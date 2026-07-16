# Noceasy

Fast installer for Noctalia v5 (Hyprland/Qt6 shell) on Arch/CachyOS.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/gabrln/Noceasy/main/install.sh | bash
```

## Development

```bash
uv sync                # install dependencies (see uv.lock)
uv run pytest          # run tests
uv run ruff check .    # lint
uv run mypy installer  # type-check
```

For details on the internal framework structure, see [installer/README.md](installer/README.md).
