module conv1_tb;
  reg clk = 0, rst = 1, in_valid = 0, in_first = 0, in_last = 0;
  reg [127:0] a = 0, w = 0;
  wire out_valid; wire signed [31:0] out_sum;
  tile dut(.clk(clk), .rst(rst), .in_valid(in_valid), .in_first(in_first),
           .in_last(in_last), .a(a), .w(w), .out_valid(out_valid), .out_sum(out_sum));
  always #5 clk = ~clk;

  reg [127:0] ma [0:6911]; reg [127:0] mw [0:6911]; reg [31:0] me [0:3455];
  integer o, b, chk = 0, errors = 0;

  always @(posedge clk) if (out_valid) begin
    if (out_sum !== me[chk]) begin
      errors = errors + 1;
      if (errors < 10) $display("MISMATCH out %0d: got %0d expected %0d", chk, out_sum, $signed(me[chk]));
    end
    chk = chk + 1;
  end

  initial begin
    $readmemh("tb/conv1_a.mem", ma); $readmemh("tb/conv1_w.mem", mw); $readmemh("tb/conv1_exp.mem", me);
    repeat (3) @(negedge clk); rst = 0;
    for (o = 0; o < 3456; o = o + 1)
      for (b = 0; b < 2; b = b + 1) begin
        @(negedge clk);
        a = ma[2*o+b]; w = mw[2*o+b];
        in_valid = 1; in_first = (b == 0); in_last = (b == 1);
      end
    @(negedge clk); in_valid = 0;
    repeat (6) @(negedge clk);
    if (errors == 0 && chk == 3456) $display("PASS: %0d conv1 outputs match PyTorch reference", chk);
    else $display("FAIL: errors=%0d outputs=%0d", errors, chk);
    $finish;
  end
endmodule
