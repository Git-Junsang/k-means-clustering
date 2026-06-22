# Step-2 local verification of IP_TOP (APB wrapper + fpu_top) with Icarus Verilog.
# Run in PowerShell (VSCode terminal):  .\hardware\sim\run_ip.ps1
$ErrorActionPreference = 'Stop'
$sim = $PSScriptRoot
$src = Join-Path $PSScriptRoot '..\src'
$out = Join-Path $env:TEMP 'ip_top_sim.vvp'
iverilog -g2012 -I "$sim\stub" -o $out `
    "$src\fpu_adder.v" `
    "$src\fpu_multiplier.v" `
    "$src\fpu_divider.v" `
    "$src\fpu_top.v" `
    "$src\IP_TOP.v" `
    "$sim\tb_ip_top.v"
if ($LASTEXITCODE -ne 0) { Write-Error "iverilog compile failed"; exit 1 }
vvp $out
