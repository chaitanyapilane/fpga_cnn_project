module demo_tb #(parameter SPLIT = 0);
  reg clk = 0, rn = 0; wire [7:0] led;
  demo_top #(.SPLIT(SPLIT)) dut(.clk(clk), .cpu_resetn(rn), .btnc(1'b0), .led(led));
  always #5 clk = ~clk;
  initial begin
    repeat (10) @(negedge clk); rn = 1;
    repeat (3000) @(negedge clk);
    $display("SPLIT=%0d led=%b  lenet %0d/128 finish-lat=%0d  smallcnn %0d/32 finish-lat=%0d  errors=%0d",
      SPLIT, led, dut.cntA, dut.endA - 50, dut.cntB, dut.endB, dut.errs);
    $finish;
  end
endmodule
