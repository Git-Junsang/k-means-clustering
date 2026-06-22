# Step 1 standalone waveform for fpu_top (QuestaSim).
# 사용법 - hardware/sim 폴더에서:  vsim -do wave_fpu_top.do
vlib work
vlog -sv ../src/fpu_adder.v ../src/fpu_multiplier.v ../src/fpu_divider.v ../src/fpu_top.v tb_fpu_top.v
vsim -voptargs=+acc work.tb_fpu_top
add wave sim:/tb_fpu_top/clk
add wave sim:/tb_fpu_top/rstnn
add wave sim:/tb_fpu_top/request_fadd
add wave sim:/tb_fpu_top/request_fsub
add wave sim:/tb_fpu_top/request_fmult
add wave sim:/tb_fpu_top/request_fdiv
add wave -radix float32 sim:/tb_fpu_top/var_x
add wave -radix float32 sim:/tb_fpu_top/var_y
add wave -radix float32 sim:/tb_fpu_top/var_z
run -all
wave zoom full
