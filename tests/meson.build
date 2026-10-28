test_common_sources = files('Test.vala')

minimal_exe = executable(
  'minimal',
  files('minimal.vala'),
  test_common_sources,
  dependencies: [xmlbird_dep, posix_dep],
)
test('minimal', minimal_exe, suite: 'unit')

benchmark_exe = executable(
  'xmlbird-benchmark',
  files('benchmark.vala'),
  test_common_sources,
  dependencies: [xmlbird_dep, posix_dep],
)
benchmark('benchmark', benchmark_exe, suite: 'benchmark')
