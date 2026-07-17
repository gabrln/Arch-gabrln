"""Tests for installer/infra/toml_cache.py — TOML manifest cache."""

from __future__ import annotations

from pathlib import Path

import pytest

from installer.infra.toml_cache import TomlCache, get_cache


class TestTomlCache:
    def test_load_valid(self, tmp_path: Path) -> None:
        d = tmp_path / "manifests"
        d.mkdir()
        (d / "test.toml").write_text("[pkg]\nname = 'foo'")
        cache = TomlCache()
        with pytest.MonkeyPatch().context() as mp:
            mp.setattr("installer.infra.toml_cache.MANIFESTS_DIR", d)
            data = cache.load("test.toml")
            assert data["pkg"]["name"] == "foo"

    def test_load_absent(self, tmp_path: Path) -> None:
        cache = TomlCache()
        data = cache.load("nonexistent.toml")
        assert data == {}

    def test_load_malformed(self, tmp_path: Path) -> None:
        d = tmp_path / "manifests"
        d.mkdir()
        (d / "bad.toml").write_text("{bad toml")
        cache = TomlCache()
        with pytest.MonkeyPatch().context() as mp:
            mp.setattr("installer.infra.toml_cache.MANIFESTS_DIR", d)
            data = cache.load("bad.toml")
            assert data == {}

    def test_get_dotted_key(self, tmp_path: Path) -> None:
        d = tmp_path / "manifests"
        d.mkdir()
        (d / "cfg.toml").write_text("[a.b]\nc = 'val'")
        cache = TomlCache()
        with pytest.MonkeyPatch().context() as mp:
            mp.setattr("installer.infra.toml_cache.MANIFESTS_DIR", d)
            assert cache.get("cfg.toml", "a.b.c") == "val"

    def test_get_default(self, tmp_path: Path) -> None:
        cache = TomlCache()
        assert cache.get("absent.toml", "x.y", default=42) == 42

    def test_get_list(self, tmp_path: Path) -> None:
        d = tmp_path / "manifests"
        d.mkdir()
        (d / "list.toml").write_text("[items]\nlist = ['a', 'b']")
        cache = TomlCache()
        with pytest.MonkeyPatch().context() as mp:
            mp.setattr("installer.infra.toml_cache.MANIFESTS_DIR", d)
            assert cache.get_list("list.toml", "items.list") == ["a", "b"]

    def test_get_list_missing(self) -> None:
        cache = TomlCache()
        assert cache.get_list("x.toml", "missing") == []

    def test_get_list_field(self, tmp_path: Path) -> None:
        d = tmp_path / "manifests"
        d.mkdir()
        (d / "tbl.toml").write_text(
            "[[pkgs]]\nname = 'a'\n[[pkgs]]\nname = 'b'\n")
        cache = TomlCache()
        with pytest.MonkeyPatch().context() as mp:
            mp.setattr("installer.infra.toml_cache.MANIFESTS_DIR", d)
            assert cache.get_list_field("tbl.toml", "pkgs", "name") == ["a", "b"]

    def test_rejects_absolute_path(self) -> None:
        cache = TomlCache()
        abs_path = str(Path.cwd().anchor) + "Windows\\System32\\config"
        with pytest.raises(ValueError, match="Absolute path"):
            cache._resolve(abs_path)

    def test_rejects_path_traversal(self, tmp_path: Path) -> None:
        cache = TomlCache()
        from installer.infra import toml_cache
        original = toml_cache.MANIFESTS_DIR
        toml_cache.MANIFESTS_DIR = tmp_path
        try:
            with pytest.raises(ValueError, match="Path traversal"):
                cache._resolve("../outside.toml")
        finally:
            toml_cache.MANIFESTS_DIR = original

    def test_global_cache(self) -> None:
        from installer.infra import toml_cache
        toml_cache._cache = None
        c1 = get_cache()
        c2 = get_cache()
        assert c1 is c2
