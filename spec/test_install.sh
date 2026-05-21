#!/usr/bin/env bash
# Spec for install targets in Makefile.
# Tests install-local and install hint behavior.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MAKE="make"
BIN_NAME="ktlg2"
FAILED=0

pass()  { echo "  PASS  $*"; }
fail()  { echo "  FAIL  $*"; FAILED=1; }

check() {
  local desc="$1"
  local expect="$2"
  local actual="$3"
  if [[ "$actual" == "$expect" ]]; then
    pass "$desc"
  else
    fail "$desc — expected: ${expect@Q}, got: ${actual@Q}"
  fi
}

# --- Setup: temp dir with fake home, dummy binary, and dummy .bashrc ---
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

FAKE_HOME="$SANDBOX/home"
mkdir -p "$FAKE_HOME/.local/bin" "$FAKE_HOME/.bashrc.d"
touch "$SANDBOX/$BIN_NAME"
chmod +x "$SANDBOX/$BIN_NAME"

# --- Test 1: install-local copies binary ---
echo "=== install-local: basic copy ==="
HOME="$FAKE_HOME" $MAKE -C "$ROOT_DIR" install-local \
  BIN_PATH="$SANDBOX/$BIN_NAME" \
  INSTALL_USERDIR="$FAKE_HOME/.local/bin" > /dev/null 2>&1

if [[ -x "$FAKE_HOME/.local/bin/$BIN_NAME" ]]; then
  pass "binary copied and executable"
else
  fail "binary not found at $FAKE_HOME/.local/bin/$BIN_NAME"
fi

# --- Test 2: install shows PATH hint when .bashrc lacks it ---
echo "=== install-local: PATH hint ==="
echo "# empty bashrc" > "$FAKE_HOME/.bashrc"

output=$(HOME="$FAKE_HOME" $MAKE -C "$ROOT_DIR" install-local \
  BIN_PATH="$SANDBOX/$BIN_NAME" \
  INSTALL_USERDIR="$FAKE_HOME/.local/bin" 2>&1 || true)

if echo "$output" | grep -q "Add ~/.local/bin to your PATH"; then
  pass "PATH hint shown when .bashrc lacks it"
else
  fail "PATH hint not shown"
fi

# --- Test 3: install skips PATH hint when .bashrc already has it ---
echo "=== install-local: no hint when already in PATH ==="
echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" > "$FAKE_HOME/.bashrc"

output=$(HOME="$FAKE_HOME" $MAKE -C "$ROOT_DIR" install-local \
  BIN_PATH="$SANDBOX/$BIN_NAME" \
  INSTALL_USERDIR="$FAKE_HOME/.local/bin" 2>&1 || true)

if echo "$output" | grep -q "Add ~/.local/bin to your PATH"; then
  fail "PATH hint shown despite existing entry"
else
  pass "no PATH hint when already in .bashrc"
fi

# --- Test 4: install target shows hint and exits non-zero ---
echo "=== install: hint message ==="
output=$($MAKE -C "$ROOT_DIR" install BIN_PATH="$SANDBOX/$BIN_NAME" 2>&1 || true)

if echo "$output" | grep -q "install-global"; then
  pass "install target mentions install-global"
else
  fail "install target does not mention install-global"
fi

# install should fail (returns non-zero via @false)
if $MAKE -C "$ROOT_DIR" install BIN_PATH="$SANDBOX/$BIN_NAME" 2>/dev/null; then
  fail "install target should exit non-zero"
else
  pass "install target exits non-zero"
fi

# --- Test 5: install-global recipe is valid (dry-run) ---
echo "=== install-global: dry-run ==="
dryrun=$($MAKE -n -C "$ROOT_DIR" install-global \
  BIN_PATH="$SANDBOX/$BIN_NAME" \
  INSTALL_SYSDIR="$SANDBOX/usr-local-bin" 2>&1 || true)

if echo "$dryrun" | grep -q "mkdir.*$SANDBOX/usr-local-bin"; then
  pass "install-global dry-run shows valid commands"
else
  fail "install-global dry-run looks wrong: $dryrun"
fi

# --- Summary ---
echo "---"
if [[ $FAILED -eq 0 ]]; then
  echo "install-spec: all tests passed"
else
  echo "install-spec: $FAILED test(s) failed"
  exit 1
fi
