#!/usr/bin/env bash
#
# mayhem/build.sh — build Wander (a 1974 non-deterministic fantasy story interpreter).
#
# Wander is a tiny, self-contained C program (4 .c files, no external deps, no build system beyond a
# hand-written Makefile). The fuzz target is the interpreter itself: it reads the player's command
# stream from STDIN and drives the world/state machine loaded from a `.misc`/`.wrld` world pair — a
# classic file-input CLI target (parity with the original mayhemheroes Mayhemfile `cmd: ./Wander`).
# There is no separate LLVMFuzzer harness, so the sanitized binary IS its own standalone reproducer.
#
# Runs inside the commit image (mayhem/Dockerfile) as `mayhem` in /mayhem. Build knobs come from the
# base image ENV (overridable); see the template for the full contract.
set -euo pipefail

# clang rejects an empty SOURCE_DATE_EPOCH — unset rather than pass "".
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}"
: "${MAYHEM_JOBS:=$(nproc)}"
: "${COVERAGE_FLAGS=}"
export SANITIZER_FLAGS DEBUG_FLAGS CC MAYHEM_JOBS COVERAGE_FLAGS

cd "$SRC"

SRCS="wand1.c wand2.c wandglb.c wandsys.c"
# gnu89 + -fcommon: this is 1980s K&R C (implicit ints, tentative common-block globals, old-style
# function definitions). Silence the pre-C23 warnings so -Werror-free clang-19 compiles it as-is;
# _GNU_SOURCE exposes stpcpy/getpid/etc.
COMPAT_FLAGS="-std=gnu89 -fcommon -D_GNU_SOURCE \
  -Wno-implicit-function-declaration -Wno-implicit-int -Wno-return-type -Wno-deprecated-non-prototype"

# 1) The fuzz TARGET: the interpreter itself, built with $SANITIZER_FLAGS + $DEBUG_FLAGS so the
#    fuzzed code is instrumented and carries DWARF<4 symbols. -O1 keeps ASan backtraces readable.
$CC $SANITIZER_FLAGS $DEBUG_FLAGS $COMPAT_FLAGS -O1 $SRCS -o /mayhem/Wander

# 2) The behavioral-oracle binary for mayhem/test.sh: the SAME program built with the project's
#    NORMAL flags (no sanitizers) so test.sh is an honest functional oracle. $COVERAGE_FLAGS
#    (empty by default) instruments this build only when a coverage pass requests it.
$CC $COVERAGE_FLAGS $COMPAT_FLAGS -O2 $SRCS -o /mayhem/Wander-test

echo "build.sh: built /mayhem/Wander (sanitized fuzz target) and /mayhem/Wander-test (oracle)" >&2
