#!/bin/bash
# Local Step-2 verification of IP_TOP (APB wrapper + fpu_top) with iverilog.
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="$ROOT/hardware/src"
SIM="$ROOT/hardware/sim"
OUT="${TMPDIR:-/tmp}/ip_top_sim"

iverilog -g2012 -I "$SIM/stub" -o "$OUT" \
    "$SRC/fpu_adder.v" \
    "$SRC/fpu_multiplier.v" \
    "$SRC/fpu_divider.v" \
    "$SRC/fpu_top.v" \
    "$SRC/IP_TOP.v" \
    "$SIM/tb_ip_top.v"

vvp "$OUT"
