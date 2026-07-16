"""Tests for installer/platform/privesc.py — privilege escalation."""

from __future__ import annotations

import subprocess
from unittest.mock import patch, MagicMock

import pytest
from installer.platform import privesc


class TestDetect:
    def test_detects_sudo_first(self) -> None:
        with patch.object(privesc.shutil, "which", return_value="/usr/bin/sudo"):
            assert privesc.detect() == privesc.Tool.sudo

    def test_detects_doas_fallback(self) -> None:
        def which_side_effect(name: str) -> str | None:
            return "/usr/bin/doas" if name == "doas" else None
        with patch.object(privesc.shutil, "which", side_effect=which_side_effect):
            assert privesc.detect() == privesc.Tool.doas

    def test_detects_run0_fallback(self) -> None:
        def which_side_effect(name: str) -> str | None:
            return "/usr/bin/run0" if name == "run0" else None
        with patch.object(privesc.shutil, "which", side_effect=which_side_effect):
            assert privesc.detect() == privesc.Tool.run0

    def test_raises_when_none_found(self) -> None:
        with patch.object(privesc.shutil, "which", return_value=None):
            with pytest.raises(RuntimeError, match="No privilege-escalation tool"):
                privesc.detect()


class TestCheckCached:
    def test_returns_true_on_exit_0(self) -> None:
        mock = MagicMock(returncode=0)
        with patch.object(privesc.subprocess, "run", return_value=mock):
            assert privesc.check_cached(privesc.Tool.sudo) is True

    def test_returns_false_on_nonzero(self) -> None:
        mock = MagicMock(returncode=1)
        with patch.object(privesc.subprocess, "run", return_value=mock):
            assert privesc.check_cached(privesc.Tool.sudo) is False

    def test_passes_correct_argv(self) -> None:
        mock = MagicMock(returncode=0)
        with patch.object(privesc.subprocess, "run", return_value=mock) as r:
            privesc.check_cached(privesc.Tool.sudo)
            assert r.call_args[0][0] == ["sudo", "-n", "true"]


class TestValidatePassword:
    def test_returns_true_on_success(self) -> None:
        mock = MagicMock(returncode=0)
        with patch.object(privesc.subprocess, "run", return_value=mock):
            assert privesc.validate_password("correct", privesc.Tool.sudo) is True

    def test_returns_false_on_failure(self) -> None:
        mock = MagicMock(returncode=1)
        with patch.object(privesc.subprocess, "run", return_value=mock):
            assert privesc.validate_password("wrong", privesc.Tool.sudo) is False

    def test_returns_false_on_file_not_found(self) -> None:
        with patch.object(privesc.subprocess, "run",
                          side_effect=FileNotFoundError):
            assert privesc.validate_password("pw", privesc.Tool.sudo) is False

    def test_returns_false_on_timeout(self) -> None:
        with patch.object(privesc.subprocess, "run",
                          side_effect=subprocess.TimeoutExpired(cmd="sudo", timeout=10)):
            assert privesc.validate_password("pw", privesc.Tool.sudo) is False


class TestEscapeForStdin:
    def test_rejects_nul(self) -> None:
        with pytest.raises(ValueError, match="NUL"):
            privesc._escape_for_stdin("pass\x00word")

    def test_accepts_normal(self) -> None:
        assert privesc._escape_for_stdin("normal") == "normal"


class TestBuildArgv:
    def test_sudo_without_password(self) -> None:
        argv, stdin = privesc._build_sudo_argv(["true"], None)
        assert argv == ["sudo", "true"]
        assert stdin is None

    def test_sudo_with_password(self) -> None:
        argv, stdin = privesc._build_sudo_argv(["true"], "secret")
        assert argv == ["sudo", "-S", "true"]
        assert stdin == "secret\n"

    def test_doas_without_password(self) -> None:
        argv, stdin = privesc._build_doas_argv(["true"], None)
        assert argv == ["doas", "true"]
        assert stdin is None

    def test_doas_with_password(self) -> None:
        argv, stdin = privesc._build_doas_argv(["true"], "secret")
        assert argv == ["doas", "true"]
        assert stdin == "secret\n"


class TestGetTool:
    def test_get_tool_caches_result(self) -> None:
        privesc.reset_tool()
        with patch.object(privesc.shutil, "which", return_value="/usr/bin/sudo"):
            t1 = privesc.get_tool()
            t2 = privesc.get_tool()
            assert t1 is t2
