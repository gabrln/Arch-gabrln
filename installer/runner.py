"""Module orchestration: the loop that runs the modules in order.

Uses rich.live.Live + rich.progress.Progress for a DankInstall-style
progress display: real-time progress tracking, spinner, and filtered
live output — all inside a single panel that redraws in place.
"""

from __future__ import annotations

import os
import sys
from dataclasses import dataclass
from pathlib import Path

from installer.errors import fatal, ModuleFailure
from installer.logger import log, set_suppress_stderr
from installer.modules.base import Module, RunContext
from installer.state import State


@dataclass
class RunnerOptions:
    dry_run: bool = False
    force: bool = False


# ── DankInstall-style TUI ───────────────────────────────────────────

def _is_tty() -> bool:
    return sys.stdout.isatty() and not os.environ.get("NO_COLOR")


class _OutputCapture:
    """Captures stdout/stderr and routes markers to the Live display.

    Markers:
        @STEP:text   -> update step description
        @CMD:text    -> update command info line
        @PROGRESS:n  -> advance progress by n steps
    Anything else goes to the live output area.
    """

    def __init__(self, live_ctx) -> None:
        self._live = live_ctx
        self._buf = b""
        self._in_write = False

    def write(self, s) -> int:
        n = len(s) if isinstance(s, str) else 0
        if self._in_write:
            return n
        self._in_write = True
        try:
            self._buf += (s if isinstance(s, (str, bytes)) else str(s)).encode()
            while b"\n" in self._buf:
                line, self._buf = self._buf.split(b"\n", 1)
                decoded = line.decode(errors="replace").rstrip()
                if not decoded:
                    continue
                if decoded.startswith("@STEP:"):
                    self._live.set_step(decoded[6:])
                elif decoded.startswith("@CMD:"):
                    self._live.set_cmd(decoded[5:])
                elif decoded.startswith("@PROGRESS:"):
                    try:
                        self._live.set_task_total(int(decoded[11:]))
                    except ValueError:
                        pass
                elif decoded.startswith("@ADVANCE:"):
                    try:
                        self._live.advance(int(decoded[10:]))
                    except ValueError:
                        pass
                else:
                    self._live.add_line(decoded)
        finally:
            self._in_write = False
        return n

    def flush(self) -> None:
        pass

    def isatty(self) -> bool:
        return True

    def fileno(self):
        return -1


class _LiveDisplay:
    """DankInstall-style progress display using rich.live + rich.progress.

    Layout:
      ╭─ Noceasy Installer 5/17 ──────────────────────────╮
      │ ⠹ Building noctalia-git                           │
      │                                                    │
      │ [████████████████░░░░░░░░░░░░░░] 3/5 packages 60% │
      │                                                    │
      │ $ yay -S --needed --noconfirm --removemake        │
      │                                                    │
      │ Live Output:                                       │
      │   ==> Making package: noctalia-git                 │
      │   -> Updating noctalia git repo...                 │
      ╰────────────────────────────────────────────────────╯

    Modules report real progress via @PROGRESS:n markers.
    When no real progress is available, a module-level bar is shown.
    """

    def __init__(self, total: int) -> None:
        self._total = total
        self._idx = 0
        self._module = ""
        self._step = ""
        self._cmd = ""
        self._lines: list[str] = []
        self._live = None
        self._console = None
        self._progress = None
        self._task_id = None
        self._task_total = 0
        self._task_done = 0
        self._use_module_bar = False  # True when no real progress

    # ── Public API ──────────────────────────────────────────────

    def start(self) -> None:
        if not _is_tty():
            return
        from rich.console import Console
        from rich.live import Live
        from rich.progress import Progress, SpinnerColumn, TextColumn, BarColumn

        self._console = Console(stderr=False)
        self._progress = Progress(
            SpinnerColumn(),
            TextColumn('[bold cyan]{task.description}'),
            BarColumn(bar_width=30),
            TextColumn('{task.percentage:>3.0f}%'),
            TextColumn('({task.completed}/{task.total})'),
            transient=False,
            console=self._console,
        )
        self._live = Live(
            self._build_renderable(),
            console=self._console,
            refresh_per_second=12,
            transient=False,
        )
        self._live.start()

    def update_module(self, name: str, idx: int) -> None:
        """Switch to a new module. Creates a new progress task."""
        self._module = name
        self._idx = idx
        self._step = f"Installing {name}"
        self._cmd = ""
        self._lines.clear()
        self._use_module_bar = True
        self._task_total = 1
        self._task_done = 0
        if self._progress and self._task_id is not None:
            self._progress.stop_task(self._task_id)
        if self._progress:
            self._task_id = self._progress.add_task(name, total=1)
        self._refresh()

    def set_step(self, step: str) -> None:
        self._step = step
        self._refresh()

    def set_cmd(self, cmd: str) -> None:
        self._cmd = cmd
        self._refresh()

    def set_task_total(self, n: int) -> None:
        """Set the real total for the current module's progress task."""
        self._task_total = n
        self._task_done = 0
        self._use_module_bar = False
        if self._progress and self._task_id is not None:
            self._progress.update(self._task_id, total=n, completed=0)
        self._refresh()

    def advance(self, n: int = 1) -> None:
        """Advance the current module's progress by n steps."""
        self._task_done += n
        if self._progress and self._task_id is not None:
            self._progress.update(self._task_id, completed=self._task_done)
        self._refresh()

    def add_line(self, line: str) -> None:
        self._lines.append(line)
        if len(self._lines) > 8:
            self._lines = self._lines[-8:]
        self._refresh()

    def finish(self) -> None:
        """Complete the current module's progress."""
        if self._progress and self._task_id is not None:
            self._progress.update(self._task_id, completed=self._task_total)
        self._refresh()

    def stop(self) -> None:
        """Stop the Live display."""
        if self._live:
            self._live.stop()

    def _refresh(self) -> None:
        if self._live:
            self._live.update(self._build_renderable())

    def _build_renderable(self):
        from rich.panel import Panel
        from rich.console import Group
        from rich.text import Text

        parts = []

        # Progress bar (from rich.progress.Progress)
        if self._progress:
            parts.append(self._progress)
        parts.append("")

        # Command info
        if self._cmd:
            parts.append(Text(f"$ {self._cmd}", style="dim"))
            parts.append("")

        # Live output (last 8 lines)
        if self._lines:
            parts.append(Text("Live Output:", style="dim"))
            for line in self._lines:
                parts.append(Text(f"  {line}"))

        return Panel(
            Group(*parts),
            title=f"Noceasy Installer [dim]{self._idx}/{self._total}[/dim]",
            border_style="cyan",
        )


# ── Runner ──────────────────────────────────────────────────────────

class ModuleRunner:
    """Executes a list of Modules in order with progress reporting."""

    def __init__(
        self,
        modules: list[Module],
        options: RunnerOptions | None = None,
    ):
        self.modules = modules
        self.options = options or RunnerOptions()
        self.state = State()

    def run_all(self) -> None:
        ctx = self._build_context()
        total = len(self.modules)
        tui = _LiveDisplay(total)
        tui.start()

        for idx, module in enumerate(self.modules, 1):
            manifest_path = self._resolve_manifest(module)

            try:
                if not self.options.force and \
                        self.state.is_up_to_date(module.name, manifest_path):
                    tui.update_module(module.name, idx)
                    tui.set_step(f"{module.name} — skip (up to date)")
                    tui.finish()
                elif self.options.dry_run:
                    tui.update_module(module.name, idx)
                    tui.set_step(f"{module.name} — dry-run")
                    tui.finish()
                else:
                    tui.update_module(module.name, idx)
                    set_suppress_stderr(True)
                    capture = _OutputCapture(tui)
                    old_stdout = sys.stdout
                    old_stderr = sys.stderr
                    sys.stdout = capture
                    sys.stderr = capture
                    try:
                        module.pre_check(ctx)
                        module.run(ctx)
                        module.post_check(ctx)
                        self.state.mark_done(module.name, manifest_path)
                    except (ModuleFailure, Exception) as exc:
                        tui.stop()
                        sys.stdout = old_stdout
                        sys.stderr = old_stderr
                        set_suppress_stderr(False)
                        if isinstance(exc, ModuleFailure):
                            self.state.mark_failed(exc.module_name, exc.reason)
                            fatal(str(exc))
                        else:
                            self.state.mark_failed(module.name, str(exc))
                            fatal(f"Module {module.name} failed: {exc}")
                    finally:
                        sys.stdout = old_stdout
                        sys.stderr = old_stderr
                        set_suppress_stderr(False)
                        tui.finish()
            except Exception as exc:
                tui.stop()
                fatal(f"Module {module.name} failed: {exc}")

        tui.stop()
        # Final summary
        from rich.console import Console
        Console(stderr=False).print(
            f"\n[bold green]✓ All {total} modules processed successfully.[/bold green]"
        )

    def _build_context(self) -> RunContext:
        real_user = os.environ.get("SUDO_USER", "")
        user_home = os.environ.get("USER_HOME", "")
        if not real_user or not user_home:
            from installer.config import STATE_DIR as _sd
            real_user = real_user or "root"
            user_home = user_home or str(Path(_sd).parent)
        return RunContext(
            real_user=real_user,
            user_home=Path(user_home),
            state=self.state,
        )

    def _resolve_manifest(self, module: Module) -> Path | None:
        if not module.manifest:
            return None
        from installer.config import MANIFESTS_DIR
        p = Path(module.manifest)
        if not p.is_absolute():
            p = MANIFESTS_DIR / p
        return p

    def _build_context(self) -> RunContext:
        real_user = os.environ.get("SUDO_USER", "")
        user_home = os.environ.get("USER_HOME", "")
        if not real_user or not user_home:
            from installer.config import STATE_DIR as _sd
            real_user = real_user or "root"
            user_home = user_home or str(Path(_sd).parent)
        return RunContext(
            real_user=real_user,
            user_home=Path(user_home),
            state=self.state,
        )

    def _resolve_manifest(self, module: Module) -> Path | None:
        if not module.manifest:
            return None
        from installer.config import MANIFESTS_DIR
        p = Path(module.manifest)
        if not p.is_absolute():
            p = MANIFESTS_DIR / p
        return p

    def _build_context(self) -> RunContext:
        real_user = os.environ.get("SUDO_USER", "")
        user_home = os.environ.get("USER_HOME", "")
        if not real_user or not user_home:
            # detect_real_user should have set these; fall back to
            # repo-relative defaults if not (e.g. running --help).
            from installer.config import STATE_DIR as _sd
            real_user = real_user or "root"
            user_home = user_home or str(Path(_sd).parent)
        return RunContext(
            real_user=real_user,
            user_home=Path(user_home),
            state=self.state,
        )

    def _resolve_manifest(self, module: Module) -> Path | None:
        if not module.manifest:
            return None
        from installer.config import MANIFESTS_DIR
        p = Path(module.manifest)
        if not p.is_absolute():
            p = MANIFESTS_DIR / p
        return p
