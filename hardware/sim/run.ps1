# Step-1 local functional verification of fpu_top with Icarus Verilog.
# Run in PowerShell (VSCode terminal):  .\hardware\sim\run.ps1
$ErrorActionPreference = 'Stop'
$sim = $PSScriptRoot
$src = Join-Path $PSScriptRoot '..\src'
$out = Join-Path $env:TEMP 'fpu_sim.vvp'
iverilog -g2012 -o $out `
    "$src\fpu_adder.v" `
    "$src\fpu_multiplier.v" `
    "$src\fpu_divider.v" `
    "$src\fpu_top.v" `
    "$sim\tb_fpu_top.v"
if ($LASTEXITCODE -ne 0) { Write-Error "iverilog compile failed"; exit 1 }
vvp $out
