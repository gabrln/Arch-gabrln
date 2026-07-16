"""Real user and home directory detection helpers.

The installer runs as the real user; ``sudo`` is only used for
individual privileged operations inside each module.
"""

from __future__ import annotations

import os
from pathlib import Path

from installer.core.errors import fatal


# ---------------------------------------------------------------------------
# Real user detection
# ---------------------------------------------------------------------------

def detect_real_user() -> tuple[str, str]:
    """Return (real_user, user_home) for the current user.

    Uses ``pwd.getpwuid`` on POSIX systems to resolve the user without relying on
    environment variables like ``SUDO_USER``. Falls back to environment variables
    on non-POSIX systems (e.g., Windows during local testing/inspection).
    """
    try:
        import pwd
        pw = pwd.getpwuid(os.getuid())
        real_user = pw.pw_name
        user_home = pw.pw_dir
    except (ImportError, AttributeError):
        real_user = os.environ.get("USERNAME") or os.environ.get("USER") or "user"
        user_home = str(Path.home())

    if not user_home or not Path(user_home).is_dir():
        fatal(f"User '{real_user}' HOME does not exist: {user_home}")

    return real_user, user_home
