project(
  'phosh-plugin-perry-torch',
  'c',
  version: '1',
  meson_version: '>= 0.60.0',
  default_options: [
    'warning_level=1',
    'werror=false',
  ],
)

libphosh_dep = dependency('libphosh-0.45')
phosh_plugins_dep = dependency('phosh-plugins')
gio_dep = dependency('gio-2.0')
gtk_dep = dependency('gtk+-3.0')

plugins_dir = phosh_plugins_dep.get_variable('quick_setting_plugins_dir')
# Same path stock Phosh plugins use for QS icons (Icon= in .plugin file).
plugin_icons_dir = get_option('prefix') / get_option('datadir') / 'phosh' / 'plugins' / 'icons'

shared_module(
  'phosh-plugin-perry-torch-quick-setting',
  files(
    'perry-torch-led.c',
    'phosh-plugin-perry-torch-quick-setting.c',
  ),
  c_args: [
    '-DG_LOG_DOMAIN="phosh-plugin-perry-torch"',
  ],
  dependencies: [libphosh_dep, phosh_plugins_dep, gio_dep, gtk_dep],
  install: true,
  install_dir: plugins_dir,
)

pluginconf = configuration_data()
pluginconf.set('plugins_dir', plugins_dir)

foreach name : ['perry-rear-torch-quick-setting', 'perry-front-torch-quick-setting']
  configure_file(
    input: name + '.plugin.in',
    output: name + '.plugin',
    configuration: pluginconf,
    install: true,
    install_dir: plugins_dir,
  )
  install_data(
    name + '-symbolic.svg',
    install_dir: plugin_icons_dir,
  )
endforeach
