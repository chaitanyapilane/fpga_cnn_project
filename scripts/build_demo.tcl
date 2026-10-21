cd C:/fpga
read_verilog rtl/tile.v
read_verilog rtl/multi_top.v
read_verilog rtl/demo_top.v
read_xdc constraints/nexys4.xdc
synth_design -top demo_top -part xc7a100tcsg324-1
opt_design
place_design
route_design
report_utilization -file results/demo_util.txt
report_timing_summary -file results/demo_timing.txt
report_power -file results/demo_power.txt
write_bitstream -force results/demo.bit
puts "DONE"
