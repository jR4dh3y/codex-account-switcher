project('codex-account-switcher', 'vala', 'c',
  version: '0.2.3',
  license: 'MIT',
  meson_version: '>= 0.59.0',
)

gnome = import('gnome')

# Dependencies
gtk4_dep = dependency('gtk4', version: '>= 4.6')
adw_dep = dependency('libadwaita-1', version: '>= 1.0')
soup_dep = dependency('libsoup-3.0')
json_dep = dependency('json-glib-1.0')

dependencies = [
  gtk4_dep,
  adw_dep,
  soup_dep,
  json_dep,
]

sources = files(
  'src/main.vala',
  'src/application.vala',
  'src/window.vala',
  'src/account_card.vala',
  'src/add_account_dialog.vala',
  'src/auth_manager.vala',
  'src/usage_checker.vala',
  'src/account_store.vala',
)

executable('codex-account-switcher',
  sources,
  dependencies: dependencies,
  install: true,
)

install_data(
  'data/io.github.jR4dh3y.CodexMultiAccountSwitcher.desktop',
  install_dir: join_paths(get_option('datadir'), 'applications'),
)

# Install app icons
icon_sizes = ['128x128', '256x256', '512x512']
foreach size : icon_sizes
  install_data(
    'data/icons/hicolor' / size / 'apps' / 'io.github.jR4dh3y.CodexAccountSwitcher.png',
    install_dir: join_paths(get_option('datadir'), 'icons', 'hicolor', size, 'apps'),
  )
endforeach
