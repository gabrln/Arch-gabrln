"""Unit tests for installer.privesc.

All subprocess calls are mocked — no real TTY or privilege-escalation
tool is required.  Tests are grouped by the three public entry points:
detect(), validate_password(), and run_privileged().
"""

from __future__ import annotations

import subprocess
from unittest import mock

import pytest

from installer.privesc import (
    Tool,
    check_cached,
    clear_cache,
    detect,
    reset_tool,
    run_privileged,
    validate_password,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture(autouse=True)
def _reset_cached_tool():
    """Ensure the module-level cached tool is cleared between tests."""
    reset_tool()
    yield
    reset_tool()


# ---------------------------------------------------------------------------
# detect()
# ---------------------------------------------------------------------------

class TestDetect:
    """Tests for the detect() function."""

    def test_sudo_found_first(self, monkeypatch: pytest.MonkeyPatch):
        """sudo is preferred when present."""
        monkeypatch.setattr(
            "installer.privesc.shutil.which",
            lambda name: "/usr/bin/" + name if name == "sudo" else None,
        )
        assert detect() is Tool.sudo

    def test_doas_fallback(self, monkeypatch: pytest.MonkeyPatch):
        """Falls back to doas when sudo is absent."""
        def fake_which(name):
            if name == "doas":
                return "/usr/bin/doas"
            return None
        monkeypatch.setattr("installer.privesc.shutil.which", fake_which)
        assert detect() is Tool.doas

    def test_run0_fallback(self, monkeypatch: pytest.MonkeyPatch):
        """Falls back to run0 when sudo and doas are absent."""
        def fake_which(name):
            if name == "run0":
                return "/usr/bin/run0"
            return None
        monkeypatch.setattr("installer.privesc.shutil.which", fake_which)
        assert detect() is Tool.run0

    def test_none_found_raises(self, monkeypatch: pytest.MonkeyPatch):
        """RuntimeError when no tool is available."""
        monkeypatch.setattr("installer.privesc.shutil.which", lambda _: None)
        with pytest.raises(RuntimeError, match="No privilege-escalation tool"):
            detect()


# ---------------------------------------------------------------------------
# check_cached()
# ---------------------------------------------------------------------------

class TestCheckCached:
    """Tests for check_cached()."""

    @pytest.mark.parametrize(
        "tool, expected_argv",
        [
            (Tool.sudo, ["sudo", "-n", "true"]),
            (Tool.doas, ["doas", "-n", "true"]),
            (Tool.run0, ["run0", "--no-ask-password", "true"]),
        ],
    )
    def test_argv_construction(
        self, tool: Tool, expected_argv: list[str], monkeypatch: pytest.MonkeyPatch
    ):
        """Each tool gets the correct cache-check argv."""
        called_with: list[list[str]] = []

        def fake_run(argv, **kwargs):
            called_with.append(list(argv))
            return subprocess.CompletedProcess(argv, 0)

        monkeypatch.setattr("installer.privesc.subprocess.run", fake_run)
        check_cached(tool)
        assert called_with == [expected_argv]

    def test_returns_true_on_zero(self, monkeypatch: pytest.MonkeyPatch):
        monkeypatch.setattr(
            "installer.privesc.subprocess.run",
            lambda *a, **kw: subprocess.CompletedProcess([], 0),
        )
        assert check_cached(Tool.sudo) is True

    def test_returns_false_on_nonzero(self, monkeypatch: pytest.MonkeyPatch):
        monkeypatch.setattr(
            "installer.privesc.subprocess.run",
            lambda *a, **kw: subprocess.CompletedProcess([], 1),
        )
        assert check_cached(Tool.sudo) is False


# ---------------------------------------------------------------------------
# validate_password()
# ---------------------------------------------------------------------------

class TestValidatePassword:
    """Tests for validate_password()."""

    def test_sudo_success(self, monkeypatch: pytest.MonkeyPatch):
        """sudo validation succeeds when password is correct."""
        monkeypatch.setattr(
            "installer.privesc.subprocess.run",
            lambda *a, **kw: subprocess.CompletedProcess([], 0),
        )
        assert validate_password("hunter2", Tool.sudo) is True

    def test_sudo_failure(self, monkeypatch: pytest.MonkeyPatch):
        """sudo validation fails with wrong password."""
        monkeypatch.setattr(
            "installer.privesc.subprocess.run",
            lambda *a, **kw: subprocess.CompletedProcess([], 1),
        )
        assert validate_password("wrong", Tool.sudo) is False

    def test_binary_not_found(self, monkeypatch: pytest.MonkeyPatch):
        """Returns False when the tool binary is missing."""
        def fake_run(*a, **kw):
            raise FileNotFoundError("sudo not found")

        monkeypatch.setattr("installer.privesc.subprocess.run", fake_run)
        assert validate_password("pw", Tool.sudo) is False

    def test_stdin_receives_password(self, monkeypatch: pytest.MonkeyPatch):
        """The password is piped to stdin with a trailing newline."""
        captured_input: list[str | None] = []

        def fake_run(argv, input=None, **kw):
            captured_input.append(input)
            return subprocess.CompletedProcess(argv, 0)

        monkeypatch.setattr("installer.privesc.subprocess.run", fake_run)
        validate_password("s3cret", Tool.sudo)
        assert captured_input == ["s3cret\n"]

    def test_nul_bytes_rejected(self):
        """Passwords containing NUL bytes raise ValueError."""
        with pytest.raises(ValueError, match="NUL bytes"):
            validate_password("pass\x00word", Tool.sudo)

    @pytest.mark.parametrize(
        "tool, expected_argv",
        [
            (Tool.sudo, ["sudo", "-S", "-v"]),
            (Tool.doas, ["doas", "-v"]),
            (Tool.run0, ["run0", "-v"]),
        ],
    )
    def test_argv_per_tool(
        self, tool: Tool, expected_argv: list[str], monkeypatch: pytest.MonkeyPatch
    ):
        """Each tool uses the correct validation argv."""
        called_with: list[list[str]] = []

        def fake_run(argv, **kwargs):
            called_with.append(list(argv))
            return subprocess.CompletedProcess(argv, 0)

        monkeypatch.setattr("installer.privesc.subprocess.run", fake_run)
        validate_password("pw", tool)
        assert called_with == [expected_argv]


# ---------------------------------------------------------------------------
# run_privileged()
# ---------------------------------------------------------------------------

class TestRunPrivileged:
    """Tests for run_privileged()."""

    # -- password injection via stdin ---------------------------------------

    def test_password_injected_when_not_cached(
        self, monkeypatch: pytest.MonkeyPatch
    ):
        """When credentials aren't cached, password is piped via stdin."""
        calls: list[tuple[list[str], str | None]] = []

        def fake_run(argv, input=None, **kwargs):
            calls.append((list(argv), input))
            return subprocess.CompletedProcess(argv, 0)

        monkeypatch.setattr("installer.privesc.subprocess.run", fake_run)
        # check_cached will return False → password must be supplied
        monkeypatch.setattr("installer.privesc.check_cached", lambda t: False)

        proc = run_privileged(
            ["pacman", "-Syu"],
            password="secret",
            tool=Tool.sudo,
        )

        assert proc.returncode == 0
        assert len(calls) == 1
        argv, stdin = calls[0]
        assert argv[:3] == ["sudo", "-S", "pacman"]
        assert stdin == "secret\n"

    def test_no_password_when_cached(self, monkeypatch: pytest.MonkeyPatch):
        """When credentials are cached and no password given, run directly."""
        calls: list[tuple[list[str], str | None]] = []

        def fake_run(argv, input=None, **kwargs):
            calls.append((list(argv), input))
            return subprocess.CompletedProcess(argv, 0)

        monkeypatch.setattr("installer.privesc.subprocess.run", fake_run)
        monkeypatch.setattr("installer.privesc.check_cached", lambda t: True)

        proc = run_privileged(
            ["ls", "/root"],
            password=None,
            tool=Tool.sudo,
        )

        assert proc.returncode == 0
        argv, stdin = calls[0]
        # sudo should NOT have -S (no password)
        assert "sudo" in argv
        assert "-S" not in argv
        assert stdin is None

    def test_no_password_not_cached_raises(
        self, monkeypatch: pytest.MonkeyPatch
    ):
        """RuntimeError when no password and cache is cold."""
        monkeypatch.setattr("installer.privesc.check_cached", lambda t: False)
        with pytest.raises(RuntimeError, match="no cached credentials"):
            run_privileged(["pacman", "-Syu"], password=None, tool=Tool.sudo)

    # -- tool auto-detection -----------------------------------------------

    def test_auto_detect_tool(self, monkeypatch: pytest.MonkeyPatch):
        """tool=None triggers detect() automatically."""
        detected: list[Tool] = []

        def fake_detect():
            detected.append(Tool.sudo)
            return Tool.sudo

        monkeypatch.setattr("installer.privesc.detect", fake_detect)
        monkeypatch.setattr("installer.privesc.check_cached", lambda t: True)
        monkeypatch.setattr(
            "installer.privesc.subprocess.run",
            lambda *a, **kw: subprocess.CompletedProcess([], 0),
        )

        run_privileged(["uptime"], tool=None)
        assert detected == [Tool.sudo]

    # -- doas and run0 argv construction -----------------------------------

    def test_doas_argv(self, monkeypatch: pytest.MonkeyPatch):
        """doas command has no -S flag — password goes via stdin."""
        calls: list[list[str]] = []

        def fake_run(argv, input=None, **kw):
            calls.append(list(argv))
            return subprocess.CompletedProcess(argv, 0)

        monkeypatch.setattr("installer.privesc.subprocess.run", fake_run)
        monkeypatch.setattr("installer.privesc.check_cached", lambda t: False)

        run_privileged(
            ["cat", "/etc/shadow"],
            password="pw",
            tool=Tool.doas,
        )

        assert calls[0][:2] == ["doas", "cat"]

    def test_run0_argv(self, monkeypatch: pytest.MonkeyPatch):
        """run0 is invoked with the target argv."""
        calls: list[list[str]] = []

        def fake_run(argv, input=None, **kw):
            calls.append(list(argv))
            return subprocess.CompletedProcess(argv, 0)

        monkeypatch.setattr("installer.privesc.subprocess.run", fake_run)
        monkeypatch.setattr("installer.privesc.check_cached", lambda t: False)

        run_privileged(
            ["systemctl", "restart", "nginx"],
            password="pw",
            tool=Tool.run0,
        )

        assert calls[0][:3] == ["run0", "systemctl", "restart"]

    # -- forwarding subprocess.run kwargs -----------------------------------

    def test_check_forwarded(self, monkeypatch: pytest.MonkeyPatch):
        """check=True is forwarded and raises on non-zero exit."""
        monkeypatch.setattr("installer.privesc.check_cached", lambda t: True)

        def fake_run(argv, **kw):
            return subprocess.CompletedProcess(argv, 1)

        monkeypatch.setattr("installer.privesc.subprocess.run", fake_run)

        with pytest.raises(subprocess.CalledProcessError):
            run_privileged(["false"], tool=Tool.sudo, check=True)

    def test_capture_output_forwarded(self, monkeypatch: pytest.MonkeyPatch):
        """capture_output is forwarded to subprocess.run."""
        def fake_run(argv, capture_output=False, **kw):
            return subprocess.CompletedProcess(
                argv, 0, stdout="hello" if capture_output else None
            )

        monkeypatch.setattr("installer.privesc.subprocess.run", fake_run)
        monkeypatch.setattr("installer.privesc.check_cached", lambda t: True)

        proc = run_privileged(
            ["echo", "hello"],
            tool=Tool.sudo,
            capture_output=True,
        )
        assert proc.stdout == "hello"

    # -- log_cmd masks password -------------------------------------------

    def test_log_cmd_masks_password(self, monkeypatch: pytest.MonkeyPatch):
        """log_cmd=True must not leak the password into debug logs."""
        logged: list[str] = []

        def fake_log(level, msg):
            logged.append(msg)

        monkeypatch.setattr("installer.privesc.log", fake_log)
        monkeypatch.setattr("installer.privesc.check_cached", lambda t: False)
        monkeypatch.setattr(
            "installer.privesc.subprocess.run",
            lambda *a, **kw: subprocess.CompletedProcess([], 0),
        )

        run_privileged(
            ["pacman", "-Syu"],
            password="s3cret",
            tool=Tool.sudo,
            log_cmd=True,
        )

        # The password string must never appear in any log line.
        for line in logged:
            assert "s3cret" not in line


# ---------------------------------------------------------------------------
# clear_cache()
# ---------------------------------------------------------------------------

class TestClearCache:
    """Tests for clear_cache()."""

    def test_sudo_clear(self, monkeypatch: pytest.MonkeyPatch):
        """sudo clears cache with -k."""
        called_with: list[list[str]] = []

        def fake_run(argv, **kwargs):
            called_with.append(list(argv))
            return subprocess.CompletedProcess(argv, 0)

        monkeypatch.setattr("installer.privesc.subprocess.run", fake_run)
        clear_cache(Tool.sudo)
        assert called_with == [["sudo", "-k"]]

    def test_run0_warns(self, monkeypatch: pytest.MonkeyPatch):
        """run0 has no cache-clear mechanism — warns but does not crash."""
        warnings: list[str] = []

        def fake_log(level, msg):
            if level == "warn":
                warnings.append(msg)

        monkeypatch.setattr("installer.privesc.log", fake_log)
        clear_cache(Tool.run0)
        assert any("no cache-clear" in w for w in warnings)
