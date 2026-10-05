module mac_tb;
  reg clk=0, rst=1; reg signed [7:0] a=0,b=0; wire signed [23:0] acc;
  mac dut(.clk(clk),.rst(rst),.a(a),.b(b),.acc(acc));
  always #5 clk=~clk;
  initial begin
    $dumpfile("mac.vcd"); $dumpvars(0,mac_tb);
    #12 rst=0; a=3; b=4; #10 a=2; b=5; #20 $display("acc=%0d",acc); $finish;
  end
endmodule
