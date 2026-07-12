#!/usr/bin/env bash
#
# mayhem/test.sh — behavioral oracle for Wander.
#
# Upstream ships NO test suite (the 1974 Makefile has only build/doc/export targets — no
# `make check`, no test sources). This oracle is therefore a KNOWN-ANSWER suite built from the
# interpreter's documented behavior against the four world files upstream ships (a3, castle,
# library, tut): each case feeds a scripted command stream on stdin and asserts specific text the
# world/state machine must produce (world loading, location descriptions, object take/inventory,
# movement + action matching, %variable% message substitution, built-in debug verbs, and the
# unknown-word path). A neutered exit(0) binary produces none of these strings and fails every case.
#
# Runs the NORMAL-flags binary /mayhem/Wander-test that mayhem/build.sh produced (never compiles).
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
cd "$SRC"

BIN=/mayhem/Wander-test
if [ ! -x "$BIN" ]; then
  echo "FATAL: $BIN missing — mayhem/build.sh must build the oracle binary" >&2
  exit 1
fi

emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

PASS=0; FAIL=0

# check <name> <world> <commands (\n-separated)> <expected substring...>
# Runs the oracle binary on the given world with the scripted stdin; every expected substring
# must appear in the combined output.
check() {
  local name="$1" world="$2" cmds="$3"; shift 3
  local out ok=1 exp
  out="$(printf '%b' "$cmds" | "$BIN" "$SRC/$world" 2>&1)"
  for exp in "$@"; do
    if ! grep -qF -- "$exp" <<<"$out"; then
      echo "FAIL: $name — missing expected output: $exp" >&2
      ok=0
    fi
  done
  if [ "$ok" -eq 1 ]; then echo "PASS: $name"; PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi
}

# a3 world: intro banner + initial location + visible object
check "a3-intro-and-location" a3 'quit\ny\n' \
  "First Under-secretary" \
  "You're in the Aldebaran III spaceport" \
  "There is a credit card here."

# object handling: take + inventory must list the taken object AND the initial possessions
check "a3-take-inventory" a3 'take card\ninventory\nquit\ny\n' \
  "Your account has 50 credits left." \
  "You are carrying some official identity papers" \
  "and a credit card"

# action matching + %variable% message substitution: the electrified fence zaps you
check "a3-blocked-move" a3 'north\nquit\ny\n' \
  "zzzZZZAAAAPPPP!" \
  "OUCH!"

# movement: south leads to the waiting room with the vending machine
check "a3-move-south" a3 'south\nlook\nquit\ny\n' \
  "tiny waiting room" \
  "insert credit card here"

# lexer: unknown words are reported verbatim
check "a3-unknown-word" a3 'flibber\nquit\ny\n' \
  'I don'"'"'t understand "flibber" ...'

# built-in debug verbs (owner mode): ~version prints compile-time parameters,
# ~snoop lists the current location's possible actions
check "a3-version-verb" a3 '~version\nquit\ny\n' \
  "MAXLOCS:1024" \
  "PATHLENGTH:1024" \
  "BUFSIZE:4096"
check "a3-snoop-verb" a3 '~snoop\nquit\ny\n' \
  "take credit card" \
  "drop official identity papers"

# the three other shipped worlds must load and print their own intro text
check "castle-intro" castle 'quit\ny\n' \
  "front of the television"
check "library-intro" library 'quit\ny\n' \
  "Through the wonder of Wander"
check "tut-intro" tut 'quit\ny\n' \
  "logical bit operations"

emit_ctrf "wander-known-answer" "$PASS" "$FAIL" 0
