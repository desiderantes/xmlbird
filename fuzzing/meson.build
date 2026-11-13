fs = import('fs')

fuzz_sources = files('fuzz.vala')

fuzz_exe = executable(
  'fuzz',
  fuzz_sources,
  dependencies: [xmlbird_dep, posix_dep],
)

fuzz_corpus_dir = meson.current_source_dir() / 'corpus'

fuzz_corpus = files(
  'corpus/test.xml',
  'corpus/minimal.xml',
  'corpus/entities_ns.xml',
  'corpus/prolog_cdata_doctype.xml',
  'corpus/many_tags.xml',
  'corpus/malformed_tag.xml',
  'corpus/unclosed_quote.xml',
  'corpus/unclosed_prolog.xml',
  'corpus/empty_ns_attr.xml',
)

test(
  'fuzz-seed',
  fuzz_exe,
  args: fuzz_corpus,
  env: {'G_DEBUG': 'fatal-warnings'},
  suite: 'fuzz',
)

afl_fuzz = find_program('afl-fuzz', required: false)

if afl_fuzz.found()
  cc = meson.get_compiler('c')
  afl_args = ['-i', fuzz_corpus_dir, '-o', meson.current_build_dir() / 'fuzz_out']

  foreach dict : [
    '/usr/share/afl/dictionaries/xml.dict',
    '/usr/share/afl++/dictionaries/xml.dict',
    '/usr/share/doc/american-fuzzy-lop/dictionaries/xml.dict',
    '/usr/share/doc/afl++/dictionaries/xml.dict',
    '/usr/share/doc/afl++-doc/dictionaries/xml.dict',
  ]
    if fs.exists(dict)
      afl_args += ['-x', dict]
      break
    endif
  endforeach

  if not cc.has_define('__AFL_COMPILER')
    message('Fuzz binary built without AFL++ instrumentation; fuzz target will use non-instrumented mode (-n). Configure with CC=afl-clang-fast for coverage-guided fuzzing.')
    afl_args += ['-n']
  endif

  fuzz_duration = get_option('fuzz_duration')
  if fuzz_duration > 0
    afl_args += ['-V', fuzz_duration.to_string()]
  endif

  afl_args += ['--', fuzz_exe, '@@']

  run_target(
    'fuzz',
    command: [afl_fuzz] + afl_args,
    env: {
      'G_DEBUG': 'fatal-warnings',
      'AFL_SKIP_CPUFREQ': '1',
      'AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES': '1',
    },
    depends: [fuzz_exe, xmlbird_lib],
  )
endif
