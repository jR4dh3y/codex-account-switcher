# Codex Account Switcher

GTK/libadwaita app for managing multiple ChatGPT accounts for Codex CLI.

![Codex Account Switcher screenshot](assets/screenshot.png)

Codex Account Switcher uses OpenAI's browser-based OAuth flow to add ChatGPT accounts without API keys. It checks Codex usage for each account, shows how much quota is left, shows when limits reset, and can write the selected account to Codex CLI's `~/.codex/auth.json`.

## Features

- Add ChatGPT accounts through OpenAI OAuth.
- See remaining Codex usage at a glance.
- Check when each account's usage window resets.
- Switch the active Codex CLI account without manually editing auth files.
- Keep last-known usage visible between app restarts.

## Build

```sh
meson setup build --prefix /usr
meson compile -C build
meson install -C build
```

## Release archive

```sh
./scripts/build-release-archive.sh 0.1.0
```
