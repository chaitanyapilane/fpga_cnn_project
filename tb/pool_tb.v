module pool_tb;
  reg clk = 0, rst = 1, in_valid = 0;
  reg [7:0] a = 0, b = 0, c = 0, d = 0;
  wire out_valid; wire [7:0] out;
  pool2x2 dut(.clk(clk), .rst(rst), .in_valid(in_valid), .a(a), .b(b), .c(c), .d(d),
              .out_valid(out_valid), .out(out));
  always #5 clk = ~clk;
  reg [7:0] x [0:3455]; reg [7:0] e [0:863];
  integer f, r, k, chk = 0, errors = 0;
  always @(posedge clk) if (out_valid) begin
    if (out !== e[chk]) begin errors = errors + 1;
      if (errors < 10) $display("MISMATCH %0d: got %0d exp %0d", chk, out, e[chk]); end
    chk = chk + 1;
  end
  initial begin
    $readmemh("tb/pp_exp.mem", x); $readmemh("tb/pool_exp.mem", e);
    repeat (3) @(negedge clk); rst = 0;
    for (f = 0; f < 6; f = f + 1) for (r = 0; r < 12; r = r + 1) for (k = 0; k < 12; k = k + 1) begin
      @(negedge clk);
      a = x[f*576 + (2*r)*24 + 2*k];     b = x[f*576 + (2*r)*24 + 2*k + 1];
      c = x[f*576 + (2*r+1)*24 + 2*k];   d = x[f*576 + (2*r+1)*24 + 2*k + 1];
      in_valid = 1;
    end
    @(negedge clk); in_valid = 0; repeat (4) @(negedge clk);
    if (errors == 0 && chk == 864) $display("PASS: %0d pooled outputs match", chk);
    else $display("FAIL: errors=%0d outputs=%0d", errors, chk);
    $finish;
  end
endmodule
