"""Noceasy installer (Python package root).

Noceasy is a fast installer for Noctalia (Hyprland/Qt6 Wayland
shell) on Arch Linux / CachyOS. This package is the install
framework itself — the bootstrap lives in install.sh; everything
from there on is modularized under clean subpackages:

Subpackages:
    core: execution engine, state management, configuration
    infra: subprocess execution, TOML caching, backups
    system: privilege escalation, user detection
    ui: logging and rich progress bars
    modules: the installation steps
"""

from __future__ import annotations

import sys

__version__ = "0.1.0"

from installer.core import config, errors, state
sys.modules["installer.config"] = config
sys.modules["installer.errors"] = errors
sys.modules["installer.state"] = state

from installer.infra import backup, exec, toml_cache
sys.modules["installer.backup"] = backup
sys.modules["installer.exec"] = exec
sys.modules["installer.toml_cache"] = toml_cache

from installer.system import privesc, user as privilege
sys.modules["installer.privesc"] = privesc
sys.modules["installer.privilege"] = privilege

from installer.ui import logger, progress
sys.modules["installer.logger"] = logger
sys.modules["installer.progress"] = progress

# Import runner last since it imports installer.modules
from installer.core import runner
sys.modules["installer.runner"] = runner

__all__ = [
    "__version__",
    "config",
    "errors",
    "runner",
    "state",
    "backup",
    "exec",
    "toml_cache",
    "privesc",
    "privilege",
    "logger",
    "progress",
]
