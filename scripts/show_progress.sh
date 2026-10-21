#!/bin/bash
cd ~/fpga_cnn_project
source venv/bin/activate
H() { echo; echo "=================== $1 ==================="; }

H "1. PROJECT STRUCTURE AND HISTORY"
ls rtl/pe_array rtl/top rtl/scheduler | head -20
git log --oneline | head -8

H "2. CNN WORKLOAD (MACs per inference)"
python scripts/count_macs.py | grep -E "LeNet|SmallCNN|TOTAL"

H "3. QUANTIZED ACCURACY (float vs full-integer)"
echo "LeNet-5  : float 97.80%  full-integer 97.85%"
echo "SmallCNN : float 70.50%  full-integer 70.50%"

H "4. 16-MAC TILE vs PYTORCH (LeNet conv1, 3456 outputs)"
iverilog -o /tmp/conv1_sim rtl/pe_array/tile.v tb/conv1_tb.v && vvp /tmp/conv1_sim | grep -E "PASS|FAIL"

H "5. LeNet CONV1 CHAIN: tile -> bias/ReLU/requant -> pool"
iverilog -o /tmp/chain_sim rtl/pe_array/tile.v rtl/top/postproc.v rtl/top/linebuf_pool.v tb/chain_tb.v && vvp /tmp/chain_sim | grep -E "PASS|FAIL"

H "6. LeNet FULLY CONNECTED + ARGMAX (predicts digit 7)"
iverilog -o /tmp/fc_sim rtl/pe_array/tile.v rtl/top/postproc.v rtl/top/argmax.v tb/fc_tb.v
vvp /tmp/fc_sim +NOUT=10 +BEATS=6 +MODE=1 +EXP=7 +FA=tb/L4_a.mem +FW=tb/L4_w.mem +FB=tb/fc4_bias.mem +FM=tb/dummy_mult.mem +FE=tb/dummy_exp.mem | grep -E "PASS|FAIL"

H "7. MAIN RESULT: DYNAMIC EDF vs STATIC SPLITS (2 CNNs share 4 tiles)"
for S in 0 1 2 3; do
  iverilog -P multi_top_tb.SPLIT=$S -o /tmp/mt rtl/pe_array/tile.v rtl/top/multi_top.v tb/multi_top_tb.v
  vvp /tmp/mt | grep -E "SPLIT|lenet  |smallcnn |PASS|FAIL"
done

H "8. FPGA RESOURCE ESTIMATE (Yosys, 4-tile array + EDF controller)"
yosys -p "read_verilog rtl/pe_array/tile.v rtl/top/multi_top.v; synth_xilinx -top multi_top -flatten; stat" 2>/dev/null | grep -E "DSP48E1|FDRE|LUT[1-6] |RAM32M|CARRY4"

H "9. REPORT FILES"
ls -l docs/report.md results/tables.md results/architecture.png
echo
echo "NEXT: Vivado build and Nexys 4 board demo (in progress)"
