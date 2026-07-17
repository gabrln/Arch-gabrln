"""Tests for installer/core/state.py — JsonStore & State."""

from __future__ import annotations

from pathlib import Path

from installer.core.state import JsonStore, State, hash_file


class TestHashFile:
    def test_hash_file_returns_hex(self, tmp_path: Path) -> None:
        f = tmp_path / "test.txt"
        f.write_text("hello")
        h = hash_file(f)
        assert isinstance(h, str)
        assert len(h) == 64

    def test_hash_file_missing(self) -> None:
        assert hash_file(Path("/nonexistent")) == ""


class TestJsonStore:
    def test_read_write_roundtrip(self, tmp_path: Path) -> None:
        store = JsonStore(tmp_path / "test.json")
        store.write({"key": "value"})
        data = store.read()
        assert data == {"key": "value"}

    def test_read_empty(self, tmp_path: Path) -> None:
        store = JsonStore(tmp_path / "nonexistent.json")
        assert store.read() == {}

    def test_read_corrupt_then_writes_clean(self, tmp_path: Path) -> None:
        p = tmp_path / "corrupt.json"
        p.write_text("{bad json")
        store = JsonStore(p)
        data = store.read()
        # Should have backed up the corrupt file and written {}
        assert data == {}
        assert p.read_text() == "{}"

    def test_context_manager_creates_lock(self, tmp_path: Path) -> None:
        p = tmp_path / "locked.json"
        store = JsonStore(p)
        with store:
            store.write({"a": 1})
        assert store.read() == {"a": 1}

    def test_get_and_set(self, tmp_path: Path) -> None:
        store = JsonStore(tmp_path / "kv.json")
        store.set("mod1", "status", "done")
        assert store.get("mod1", "status") == "done"

    def test_get_missing(self, tmp_path: Path) -> None:
        store = JsonStore(tmp_path / "kv.json")
        assert store.get("nonexistent", "field") == ""

    def test_lock_timeout_raises(self, tmp_path: Path) -> None:
        """When fcntl is None the lock step is skipped; no error raised."""
        store = JsonStore(tmp_path / "notimeout.json")
        with store:
            store.write({"ok": True})
        assert store.read() == {"ok": True}


class TestState:
    def test_is_up_to_date_false_when_not_done(self, tmp_path: Path) -> None:
        state = State(path=tmp_path / "state.json", dir_=tmp_path)
        assert not state.is_up_to_date("mod1", None)

    def test_mark_done_then_is_up_to_date(self, tmp_path: Path) -> None:
        state = State(path=tmp_path / "state.json", dir_=tmp_path)
        state.mark_done("mod1", None)
        assert state.is_up_to_date("mod1", None)

    def test_is_up_to_date_with_manifest(self, tmp_path: Path) -> None:
        manifest = tmp_path / "manifest.toml"
        manifest.write_text("[pkg]\nname = 'foo'")
        state = State(path=tmp_path / "state.json", dir_=tmp_path)
        state.mark_done("mod1", manifest)
        assert state.is_up_to_date("mod1", manifest)

    def test_is_up_to_date_false_after_manifest_change(self, tmp_path: Path) -> None:
        manifest = tmp_path / "manifest.toml"
        manifest.write_text("[pkg]\nname = 'foo'")
        state = State(path=tmp_path / "state.json", dir_=tmp_path)
        state.mark_done("mod1", manifest)
        manifest.write_text("[pkg]\nname = 'bar'")
        assert not state.is_up_to_date("mod1", manifest)

    def test_mark_failed(self, tmp_path: Path) -> None:
        state = State(path=tmp_path / "state.json", dir_=tmp_path)
        state.mark_failed("mod1", "something broke")
        assert state.get("mod1", "status") == "failed"
        assert state.get("mod1", "failure_reason") == "something broke"

    def test_create_dir_if_missing(self, tmp_path: Path) -> None:
        d = tmp_path / "new_state_dir"
        state = State(path=d / "state.json", dir_=d)
        assert d.is_dir()
        state.mark_done("mod1", None)
        assert state.is_up_to_date("mod1", None)
