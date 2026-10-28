fuzz_sources = files('fuzz.vala')

fuzz_exe = executable(
  'fuzz',
  fuzz_sources,
  dependencies: [xmlbird_dep, posix_dep],
)

test(
  'fuzz-seed',
  fuzz_exe,
  args: [files('test.xml')],
  suite: 'fuzz',
)

radamsa = find_program('radamsa', required: true)

if radamsa.found()
  fuzz_cmd = 'i=0; echo "Starting fuzzing with radamsa... Press Ctrl+C to stop."; while true; do @0@ @1@ > fuzzed.xml && if ! @2@ fuzzed.xml; then echo "Crash found at iteration $i! Saved reproducer to crash.xml"; cp fuzzed.xml crash.xml; exit 1; fi; i=$((i+1)); if [ $((i % 100)) -eq 0 ]; then echo "Fuzzed $i iterations..."; fi; done'.format(
    radamsa.full_path(),
    meson.current_source_dir() / 'test.xml',
    fuzz_exe.full_path(),
  )

  run_target(
    'fuzz',
    command: [find_program('sh'), '-c', fuzz_cmd],
    depends: fuzz_exe,
  )
else
  run_target(
    'fuzz',
    command: [
      find_program('sh'),
      '-c',
      'echo "radamsa was not found in PATH. Please install radamsa to run iterative fuzzing."; exit 1',
    ],
    depends: fuzz_exe,
  )
endif
