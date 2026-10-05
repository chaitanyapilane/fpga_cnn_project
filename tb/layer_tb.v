module layer_tb;
  reg clk = 0, rst = 1, in_valid = 0, in_first = 0, in_last = 0;
  reg [127:0] a = 0, w = 0;
  wire out_valid; wire signed [31:0] out_sum;
  tile dut(.clk(clk), .rst(rst), .in_valid(in_valid), .in_first(in_first),
           .in_last(in_last), .a(a), .w(w), .out_valid(out_valid), .out_sum(out_sum));
  always #5 clk = ~clk;

  reg [127:0] ma [0:16383]; reg [127:0] mw [0:16383]; reg [31:0] me [0:4095];
  integer nout, beats, o, b, chk = 0, errors = 0;
  reg [8*64-1:0] fa, fw, fe;

  always @(posedge clk) if (out_valid) begin
    if (out_sum !== me[chk]) begin
      errors = errors + 1;
      if (errors < 10) $display("MISMATCH out %0d: got %0d expected %0d", chk, out_sum, $signed(me[chk]));
    end
    chk = chk + 1;
  end

  initial begin
    if (!$value$plusargs("NOUT=%d", nout) || !$value$plusargs("BEATS=%d", beats) ||
        !$value$plusargs("FA=%s", fa) || !$value$plusargs("FW=%s", fw) ||
        !$value$plusargs("FE=%s", fe)) begin $display("missing plusargs"); $finish; end
    $readmemh(fa, ma); $readmemh(fw, mw); $readmemh(fe, me);
    repeat (3) @(negedge clk); rst = 0;
    for (o = 0; o < nout; o = o + 1)
      for (b = 0; b < beats; b = b + 1) begin
        @(negedge clk);
        a = ma[o*beats+b]; w = mw[o*beats+b];
        in_valid = 1; in_first = (b == 0); in_last = (b == beats-1);
      end
    @(negedge clk); in_valid = 0;
    repeat (6) @(negedge clk);
    if (errors == 0 && chk == nout) $display("PASS: %0d outputs x %0d beats", chk, beats);
    else $display("FAIL: errors=%0d outputs=%0d/%0d", errors, chk, nout);
    $finish;
  end
endmodule
