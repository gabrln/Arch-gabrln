"""Module orchestration: the loop that runs the modules in order."""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

from installer.errors import fatal, ModuleFailure
from installer.logger import log, set_suppress_stderr
from installer.modules.base import Module, RunContext
from installer.progress import make_progress
from installer.state import State


@dataclass
class RunnerOptions:
    dry_run: bool = False
    force: bool = False


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
        self._loop(ctx)

    def _loop(self, ctx: RunContext) -> None:
        total = len(self.modules)
        width = len(str(total))

        for idx, module in enumerate(self.modules, 1):
            manifest_path = self._resolve_manifest(module)
            tag = f"[{idx:>{width}}/{total}]"

            try:
                if not self.options.force and \
                        self.state.is_up_to_date(module.name, manifest_path):
                    print(f"{tag} {module.name:<28} skip (up to date)")
                elif self.options.dry_run:
                    print(f"{tag} {module.name:<28} dry-run")
                else:
                    print(f"{tag} {module.name:<28} running...", end=" ",
                          flush=True)
                    set_suppress_stderr(True)
                    try:
                        module.pre_check(ctx)
                        module.run(ctx)
                        module.post_check(ctx)
                        self.state.mark_done(module.name, manifest_path)
                    finally:
                        set_suppress_stderr(False)
                    print("done")
            except ModuleFailure as exc:
                print("FAILED")
                self.state.mark_failed(exc.module_name, exc.reason)
                fatal(str(exc))
            except Exception as exc:
                print("FAILED")
                self.state.mark_failed(module.name, str(exc))
                fatal(f"Module {module.name} failed: {exc}")

        print(f"\n[OK] All {total} modules processed.")

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
