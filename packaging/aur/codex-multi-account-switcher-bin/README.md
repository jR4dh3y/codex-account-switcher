# codex-multi-account-switcher-bin

This AUR package repackages the GitHub release archive produced by this repository.

## Release flow

1. Bump `project(version:)` in `meson.build`.
2. Push a matching tag such as `v0.1.0`.
3. GitHub Actions uploads `codex-account-switcher-0.1.0-x86_64.tar.zst` and its `.sha256` file to the release.
4. Replace `sha256sums=('SKIP')` in `PKGBUILD` and `.SRCINFO` with the generated checksum if you want strict AUR verification.
5. Publish `packaging/aur/codex-multi-account-switcher-bin` to the AUR as `codex-multi-account-switcher-bin`.
