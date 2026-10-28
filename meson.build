project(
    'xmlbird',
    'vala',
    'c',
    version: '1.2.15',
    license: 'LGPL-3.0-or-later',
    meson_version: '>= 1.11.0',
    default_options: [
        'warning_level=1',
        'buildtype=debugoptimized',
    ],
)

vala_args = ['--enable-experimental']

if get_option('experimental_non_null')
    vala_args += ['--enable-experimental-non-null']
endif

add_project_arguments(vala_args, language: 'vala')

glib_dep = dependency('glib-2.0')
gobject_dep = dependency('gobject-2.0')
valac = meson.get_compiler('vala')
posix_dep = valac.find_library('posix')

xmlbird_sources = files(
    'libxmlbird/Attribute.vala',
    'libxmlbird/Attributes.vala',
    'libxmlbird/Elements.vala',
    'libxmlbird/Tag.vala',
    'libxmlbird/XmlData.vala',
    'libxmlbird/XmlElement.vala',
    'libxmlbird/XmlString.vala',
    'libxmlbird/XmlTree.vala',
    'libxmlbird/Xml.vala',
)

xmlbird_lib = shared_library(
    'xmlbird',
    xmlbird_sources,
    dependencies: [glib_dep, gobject_dep, posix_dep],
    vala_header: 'xmlbird.h',
    vala_vapi: 'xmlbird.vapi',
    version: meson.project_version(),
    soversion: '1',
    install: true,
    install_vala_header: true,
    install_vala_vapi: true,
)

xmlbird_dep = declare_dependency(
    link_with: xmlbird_lib,
    include_directories: include_directories('.'),
    dependencies: [glib_dep, gobject_dep],
)

pkg = import('pkgconfig')
pkg.generate(
    xmlbird_lib,
    name: 'xmlbird',
    filebase: 'xmlbird',
    description: 'XML parser',
    version: meson.project_version(),
    url: 'https://birdfont.org/xmlbird.php',
    requires: glib_dep.name(),
)

if get_option('tests')
    subdir('tests')
endif

if get_option('fuzzing')
    subdir('fuzzing')
endif
