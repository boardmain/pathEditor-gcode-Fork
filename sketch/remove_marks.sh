#!/usr/bin/env bash
set -e

# Wrapper script to call the Python cleaner
# Usage: ./remove_marks.sh <file.gcode>
# This script invokes remove_marks.py which modifies the gcode
# to neutralize registration marks (setting Z to 0.0) instead of removing them.

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
PYTHON_SCRIPT="$DIR/remove_marks.py"

if [[ $# -lt 1 ]]; then
  echo "Uso: $0 <file.gcode>"
  exit 1
fi

INPUT_GCODE="$1"

if [[ ! -f "$INPUT_GCODE" ]]; then
  echo "Errore: file $INPUT_GCODE non trovato."
  exit 1
fi

python3 "$PYTHON_SCRIPT" "$INPUT_GCODE"
