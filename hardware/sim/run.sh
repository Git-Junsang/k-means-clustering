#!/bin/bash
# Local Step-1 functional verification of fpu_top with iverilog.
# Usage:  ./hardware/sim/run.sh   (run from repo root, or anywhere)
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="$ROOT/hardware/src"
SIM="$ROOT/hardware/sim"
OUT="${TMPDIR:-/tmp}/fpu_sim"

iverilog -g2012 -o "$OUT" \
    "$SRC/fpu_adder.v" \
    "$SRC/fpu_multiplier.v" \
    "$SRC/fpu_divider.v" \
    "$SRC/fpu_top.v" \
    "$SIM/tb_fpu_top.v"

vvp "$OUT"
