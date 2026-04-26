# Codex Multi-Account Switcher

GTK/libadwaita app for adding ChatGPT accounts, checking Codex usage, and switching the active Codex CLI account.

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
