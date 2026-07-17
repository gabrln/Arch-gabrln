"""Noceasy installer (Python package root).

Noceasy is a fast installer for Noctalia (Hyprland/Qt6 Wayland
shell) on Arch Linux / CachyOS. This package is the install
framework itself — the bootstrap lives in install.sh; everything
from there on is modularized under clean subpackages:

Subpackages:
    core: execution engine, state management, configuration
    infra: subprocess execution, TOML caching, backups
    platform: privilege escalation, user detection
    ui: logging and rich progress bars
    modules: the installation steps
"""

from __future__ import annotations

__version__ = "0.1.0"

__all__ = [
    "__version__",
]
