"""15-system-tweaks: root theme symlinks + perms + cleanup."""

from __future__ import annotations

import os
import shutil
from pathlib import Path

from installer.modules.base import Module, RunContext
from installer.modules.mixins import chown_user
from installer.platform import privesc
from installer.ui.logger import log


def _replace_with_symlink(link_path: Path, target: Path,
                          sudo_password: str | None = None) -> None:
    """Make `link_path` a symlink to `target`, removing anything in the way.

    If `link_path` is already a valid symlink to `target`, no-op.
    If it's a directory, rmtree. If it's a file or wrong symlink,
    unlink. Then create the symlink.

    For paths under /root/, uses privesc since the process is not root.
    """
    if link_path.is_symlink() and os.readlink(link_path) == str(target):
        log("info", f"  -> {link_path} (already correct)")
        return
    # For /root/ paths, use privesc for all operations
    if str(link_path).startswith("/root/"):
        if link_path.is_dir() and not link_path.is_symlink():
            privesc.run_privileged(["rm", "-rf", str(link_path)], sudo_password)
        elif link_path.is_symlink() or link_path.is_file():
            privesc.run_privileged(["rm", "-f", str(link_path)], sudo_password)
        privesc.run_privileged(
            ["ln", "-s", str(target), str(link_path)], sudo_password)
    else:
        if link_path.is_dir() and not link_path.is_symlink():
            shutil.rmtree(link_path)
        elif link_path.is_symlink() or link_path.is_file():
            link_path.unlink()
        link_path.symlink_to(target)
    log("info", f"  -> {link_path}")


class SystemTweaksModule(Module):
    name = "15-system-tweaks"

    def run(self, ctx: RunContext) -> None:
        log("info", "Adjusting user config permissions...")
        cfg = ctx.user_home / ".config"
        if cfg.exists():
            chown_user(cfg, ctx.real_user)
        icons_dir = ctx.user_home / ".local" / "share" / "icons"
        icons_dir.mkdir(parents=True, exist_ok=True)
        chown_user(icons_dir, ctx.real_user)

        log("info", "Linking themes for root app accessibility...")
        privesc.run_privileged(
            ["mkdir", "-p", "/root/.config", "/root/.local/share"],
            ctx.sudo_password,
        )

        for root_cfg in ("gtk-3.0", "gtk-4.0"):
            target = ctx.user_home / ".config" / root_cfg
            link_path = Path(f"/root/.config/{root_cfg}")
            if not target.exists():
                log("warn",
                    f"Target {target} does not exist; skipping {link_path}.")
                continue
            _replace_with_symlink(link_path, target, ctx.sudo_password)

        # Icons
        user_icons = ctx.user_home / ".local" / "share" / "icons"
        root_icons = Path("/root/.local/share/icons")
        if user_icons.exists():
            _replace_with_symlink(root_icons, user_icons, ctx.sudo_password)

        # Cleanup orphan configs
        log("info", "Cleaning orphan Noctalia configs...")
        qt5 = ctx.user_home / ".config" / "qt5ct"
        if qt5.exists():
            shutil.rmtree(qt5)
        qt6_qt6 = ctx.user_home / ".config" / "qt6ct" / "qt6ct"
        if qt6_qt6.is_symlink():
            qt6_qt6.unlink()
            log("info", "  -> circular symlink qt6ct/qt6ct removed")

        log("success", "System tweaks applied.")
