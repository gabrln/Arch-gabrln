"""17-dev-tools: install dev helper scripts to ~/.local/bin/.

Syncs every `*.py` file under `installer/dev/` to `~/.local/bin/<stem>`,
stripping the `.py` extension and making the target executable.

This keeps dev tooling in the repo (versioned, reviewable) while
giving the user a clean system-wide binary in their `$PATH`. After
each `install.sh` run, the installed script matches the in-repo
source; out-of-band edits are overwritten on the next install.

If `installer/dev/` is empty or absent, the module is a no-op.
"""

from __future__ import annotations

import os
import shutil
from pathlib import Path

from installer.core.config import REPO_DIR
from installer.modules.base import Module, RunContext
from installer.modules.mixins import chown_user
from installer.ui.logger import log

DEV_SRC: Path = REPO_DIR / "installer" / "dev"
DEV_DST: Path = Path.home() / ".local" / "bin"


def _install_one(src: Path, dst_dir: Path, user: str) -> None:
    """Copy `src` to `dst_dir/<src.stem>` and make it executable."""
    dst = dst_dir / src.stem
    # Remove anything in the way: file, symlink, or stale dir.
    if dst.is_symlink() or dst.is_file():
        dst.unlink()
    elif dst.is_dir():
        shutil.rmtree(dst)
    dst.write_text(src.read_text(encoding="utf-8"), encoding="utf-8")
    dst.chmod(0o755)
    chown_user(dst, user)
    log("info", f"  -> {dst}")


class DevToolsModule(Module):
    name = "17-dev-tools"
    # No manifest: this module reads from REPO_DIR/installer/dev/
    # directly, which is part of the framework, not a declarative file.

    def run(self, ctx: RunContext) -> None:
        if not DEV_SRC.is_dir():
            log("info", f"{DEV_SRC} not found. Skipping dev-tools sync.")
            return

        scripts = sorted(DEV_SRC.glob("*.py"))
        if not scripts:
            log("info", "No dev scripts to install.")
            return

        DEV_DST.mkdir(parents=True, exist_ok=True)
        chown_user(DEV_DST, ctx.real_user)

        log("info", f"Syncing {len(scripts)} dev tool(s) to {DEV_DST}...")
        for src in scripts:
            _install_one(src, DEV_DST, ctx.real_user)

        # Final sanity check: PATH includes ~/.local/bin for this user.
        # We don't try to mutate shell rc files (fragile); just log a
        # hint if the dir is not on PATH for interactive shells.
        path = os.environ.get("PATH", "")
        if str(DEV_DST) not in path:
            log("warn",
                f"{DEV_DST} is not on PATH. Add it to your shell rc "
                f"(export PATH=\"$HOME/.local/bin:$PATH\") to use the "
                f"installed scripts without a full path.")

        log("success", f"Dev tools installed ({len(scripts)} script(s)).")
