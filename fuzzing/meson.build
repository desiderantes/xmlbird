fs = import('fs')

fuzz_sources = files('fuzz.vala')

fuzz_exe = executable(
  'xmlbird-fuzz',
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
  'corpus/bom_utf8.xml',
  'corpus/bom_utf16_mismatch.xml',
  'corpus/utf8_markup.xml',
  'corpus/embedded_nul.xml',
  'corpus/dtd_entities.xml',
  'corpus/dtd_nested_quotes.xml',
  'corpus/cdata_and_comments_inner.xml',
  'corpus/attrs_whitespace_quotes.xml',
  'corpus/same_name_nesting.xml',
  'corpus/misnested_tags.xml',
  'corpus/entity_roundtrip_edge.xml',
  'corpus/deep_nesting.xml',
  'corpus/over_max_depth.xml',
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

  afl_args += ['-x', meson.current_source_dir() / 'extra.dict']

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
