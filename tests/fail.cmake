# These fail on Mac because the GNU ed version is old and does
# not understand \< \> \s.
set(SKIP_TESTS
  ed-inputs/regexp-escape.cmd
  ed-inputs/regexp-escape2.cmd
)
