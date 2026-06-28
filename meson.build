project('singularity-installer', ['vala', 'c'],
  version: '0.1.0',
  meson_version: '>= 0.59.0'
)

gtk_dep            = dependency('gtk4')
gee_dep            = dependency('gee-0.8')
json_dep           = dependency('json-glib-1.0')
xml_dep            = dependency('libxml-2.0')

libsingularity_dep = dependency('singularity-1.0',
  fallback: ['libsingularity', 'libsingularity_dep']
)

if not meson.is_subproject() and libsingularity_dep.type_name() == 'internal'
  libsingularity_vapi_dir = join_paths(meson.project_build_root(), 'subprojects', 'libsingularity')
  add_project_arguments(['--vapidir=' + libsingularity_vapi_dir], language: 'vala')
endif

executable('singularity-installer',
  [
    'src/main.vala',
    'src/app.vala',
    'src/window.vala',
    'src/kbd.vala',
  ],
  dependencies: [gtk_dep, gee_dep, json_dep, xml_dep, libsingularity_dep,
                 meson.get_compiler('c').find_library('m', required: true)],
  vala_args: ['--pkg=posix'],
  install: true
)

install_data('data/dev.sinty.installer.desktop',
  install_dir: get_option('datadir') / 'applications'
)

install_data('data/icons/dev.sinty.installer.svg',
  install_dir: get_option('datadir') / 'icons' / 'hicolor' / 'scalable' / 'apps'
)
