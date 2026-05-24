#!/usr/bin/env bash
set -euo pipefail

# test-my-case.sh — прогнать ktlg2 на тестовых данных.
#
# Подготавливает копию tests/data → tests/target и запускает ktlg2
# с указанной командой и опциями.
#
# Usage:
#   distrib/test-my-case.sh [command] [options...]
#
# Examples:
#   distrib/test-my-case.sh                  # organize (по умолчанию)
#   distrib/test-my-case.sh organize --dry-run -v
#   distrib/test-my-case.sh rename
#   distrib/test-my-case.sh rename --dry-run --json
#   distrib/test-my-case.sh touch --dry-run
#   distrib/test-my-case.sh plane
#   distrib/test-my-case.sh check --json
#   distrib/test-my-case.sh dups --dry-run
#
# Переменные окружения:
#   KTLG2_BIN    путь к бинарнику (по умолчанию ./bin/ktlg2)

SCRIPT_DIR="$(cd "$(dirname "$(realpath "$0")")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR/tests"

KTLG2_BIN="${KTLG2_BIN:-$PROJECT_DIR/bin/ktlg2}"
CMD="${1:-organize}"
# Сдвигаем аргументы, если команда задана
if [[ $# -gt 0 ]]; then
  shift
fi

# Проверить бинарник
if [[ ! -x "$KTLG2_BIN" ]]; then
  echo "ERROR: binary not found or not executable: $KTLG2_BIN" >&2
  echo "  Set KTLG2_BIN or run 'make build' first." >&2
  exit 1
fi

# --- подготовка ---
echo ">>> Prepare: data -> target"
rm -rf target
# Почистить артефакты от предыдущих запусков ktlg2
rm -rf target.years* target.problems* target.dups*
cp -a data target

TARGET_DIR="$PWD/target"

echo ">>> Run: $KTLG2_BIN $CMD $* $TARGET_DIR"
echo ""
set +e
"$KTLG2_BIN" "$CMD" "$@" "$TARGET_DIR"
exit_code=$?
set -e

echo ""
if [[ $exit_code -eq 0 ]]; then
  echo ">>> OK (exit code: $exit_code)"
else
  echo ">>> FAIL (exit code: $exit_code)" >&2
fi

exit $exit_code
