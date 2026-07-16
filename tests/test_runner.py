"""Tests for installer/core/runner.py — ModuleRunner."""

from __future__ import annotations

from pathlib import Path
from unittest.mock import MagicMock, patch

from installer.core.runner import ModuleRunner, RunnerOptions
from installer.modules.base import Module, RunContext


class _FakeModule(Module):
    name = "test-module"

    def run(self, ctx: RunContext) -> None:
        pass


class _FailingModule(Module):
    name = "failing-module"

    def run(self, ctx: RunContext) -> None:
        raise RuntimeError("intentional failure")


class TestSetupPrivileges:
    def test_dry_run_skips_password_prompt(self) -> None:
        runner = ModuleRunner(
            modules=[],
            options=RunnerOptions(dry_run=True),
        )
        ctx = RunContext(real_user="test", user_home=Path("/home/test"),
                         state=MagicMock())
        tui = MagicMock()
        with patch("installer.platform.privesc") as mock_privesc:
            runner._setup_privileges(ctx, tui)
            mock_privesc.validate_password.assert_not_called()
            assert ctx.sudo_password is None

    def test_dry_run_skips_detect_if_cached(self) -> None:
        runner = ModuleRunner(
            modules=[],
            options=RunnerOptions(dry_run=True),
        )
        ctx = RunContext(real_user="test", user_home=Path("/home/test"),
                         state=MagicMock())
        tui = MagicMock()
        with patch("installer.platform.privesc") as mock_privesc:
            mock_privesc.check_cached.return_value = True
            runner._setup_privileges(ctx, tui)
            mock_privesc.validate_password.assert_not_called()
            assert ctx.sudo_password is None


class TestRunSingleModule:
    def test_dry_run_skips_execution(self) -> None:
        mod = _FakeModule()
        runner = ModuleRunner(
            modules=[mod],
            options=RunnerOptions(dry_run=True),
        )
        ctx = RunContext(real_user="test", user_home=Path("/home/test"),
                         state=MagicMock())
        tui = MagicMock()
        with patch.object(mod, "run") as mock_run:
            runner._run_single_module(mod, 1, ctx, tui)
            mock_run.assert_not_called()

    def test_skip_up_to_date(self) -> None:
        mod = _FakeModule()
        state = MagicMock()
        state.is_up_to_date.return_value = True
        runner = ModuleRunner(
            modules=[mod],
            options=RunnerOptions(),
        )
        runner.state = state
        ctx = RunContext(real_user="test", user_home=Path("/home/test"),
                         state=state)
        tui = MagicMock()
        with patch.object(mod, "run") as mock_run:
            runner._run_single_module(mod, 1, ctx, tui)
            mock_run.assert_not_called()

    def test_runs_module_normally(self) -> None:
        mod = _FakeModule()
        state = MagicMock()
        state.is_up_to_date.return_value = False
        runner = ModuleRunner(
            modules=[mod],
            options=RunnerOptions(),
        )
        runner.state = state
        ctx = RunContext(real_user="test", user_home=Path("/home/test"),
                         state=state)
        tui = MagicMock()
        with patch.object(mod, "run") as mock_run:
            runner._run_single_module(mod, 1, ctx, tui)
            mock_run.assert_called_once()

    def test_failure_calls_fatal(self) -> None:
        mod = _FailingModule()
        state = MagicMock()
        state.is_up_to_date.return_value = False
        runner = ModuleRunner(
            modules=[mod],
            options=RunnerOptions(),
        )
        runner.state = state
        ctx = RunContext(real_user="test", user_home=Path("/home/test"),
                         state=state)
        tui = MagicMock()
        with patch("installer.core.runner.fatal") as mock_fatal:
            runner._run_single_module(mod, 1, ctx, tui)
            mock_fatal.assert_called_once()
            assert "failing-module" in str(mock_fatal.call_args)
