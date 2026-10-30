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

afl_fuzz = find_program('afl-fuzz', required: false)

if afl_fuzz.found()
  fuzz_cmd = '''
    set -e
    SEED_DIR="@0@/fuzz_in"
    OUT_DIR="@0@/fuzz_out"
    mkdir -p "$SEED_DIR" "$OUT_DIR"
    cp "@1@" "$SEED_DIR/test.xml"
    EXTRA_ARGS=""
    for dict in /usr/share/afl/dictionaries/xml.dict /usr/share/doc/american-fuzzy-lop/dictionaries/xml.dict; do
      if [ -f "$dict" ]; then
        EXTRA_ARGS="$EXTRA_ARGS -x $dict"
        break
      fi
    done
    if ! grep -qa "__AFL_SHM_ID" "@2@" "@3@" 2>/dev/null; then
      echo "Note: Binary built without AFL++ instrumentation; running in non-instrumented mode (-n)."
      echo "Tip: Reconfigure with CC=afl-clang-fast or CC=afl-gcc-fast for coverage-guided fuzzing."
      EXTRA_ARGS="$EXTRA_ARGS -n"
    fi
    export AFL_SKIP_CPUFREQ=1
    export AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1
    exec "@4@" -i "$SEED_DIR" -o "$OUT_DIR" $EXTRA_ARGS -- "@2@" @@
  '''.format(
    meson.current_build_dir(),
    meson.current_source_dir() / 'test.xml',
    fuzz_exe.full_path(),
    xmlbird_lib.full_path(),
    afl_fuzz.full_path(),
  )

  run_target(
    'fuzz',
    command: [find_program('sh'), '-c', fuzz_cmd],
    depends: [fuzz_exe, xmlbird_lib],
  )
else
  run_target(
    'fuzz',
    command: [
      find_program('sh'),
      '-c',
      'echo "afl-fuzz was not found in PATH. Please install AFL++ (afl++ / american-fuzzy-lop) to run iterative fuzzing."; exit 1',
    ],
    depends: fuzz_exe,
  )
endif
