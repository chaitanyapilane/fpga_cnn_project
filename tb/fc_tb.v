module fc_tb;
  reg clk = 0, rst = 1, in_valid = 0, in_first = 0, in_last = 0;
  reg [127:0] a = 0, w = 0;
  wire t_valid; wire signed [31:0] t_sum;
  tile u_t(.clk(clk), .rst(rst), .in_valid(in_valid), .in_first(in_first), .in_last(in_last),
           .a(a), .w(w), .out_valid(t_valid), .out_sum(t_sum));
  always #5 clk = ~clk;

  reg [31:0] bias_tab [0:127]; reg [15:0] mult_m [0:0];
  integer nsum = 0;
  always @(posedge clk) if (t_valid) nsum <= nsum + 1;
  wire signed [31:0] bias = bias_tab[nsum];

  wire p_valid; wire [7:0] p_out;
  postproc u_p(.clk(clk), .rst(rst), .in_valid(t_valid), .sum(t_sum), .bias(bias),
               .mult(mult_m[0]), .out_valid(p_valid), .out(p_out));
  wire g_valid; wire [3:0] g_idx;
  argmax #(.N(10)) u_g(.clk(clk), .rst(rst), .in_valid(t_valid), .score(t_sum + bias),
                       .out_valid(g_valid), .idx(g_idx));

  reg [127:0] ma [0:4095]; reg [127:0] mw [0:4095]; reg [7:0] e [0:127];
  integer nout, beats, mode, expd, o, b, chk = 0, errors = 0, digit = -1;
  reg [8*64-1:0] fa, fw, fb, fm, fe;

  always @(posedge clk) begin
    if (p_valid && mode == 0) begin
      if (p_out !== e[chk]) begin errors = errors + 1;
        if (errors < 10) $display("MISMATCH %0d: got %0d exp %0d", chk, p_out, e[chk]); end
      chk = chk + 1;
    end
    if (g_valid && mode == 1) digit = g_idx;
  end

  initial begin
    if (!$value$plusargs("NOUT=%d", nout) || !$value$plusargs("BEATS=%d", beats) ||
        !$value$plusargs("MODE=%d", mode) || !$value$plusargs("EXP=%d", expd) ||
        !$value$plusargs("FA=%s", fa) || !$value$plusargs("FW=%s", fw) ||
        !$value$plusargs("FB=%s", fb) || !$value$plusargs("FM=%s", fm) ||
        !$value$plusargs("FE=%s", fe)) begin $display("missing plusargs"); $finish; end
    $readmemh(fa, ma); $readmemh(fw, mw); $readmemh(fb, bias_tab);
    $readmemh(fm, mult_m); $readmemh(fe, e);
    repeat (3) @(negedge clk); rst = 0;
    for (o = 0; o < nout; o = o + 1)
      for (b = 0; b < beats; b = b + 1) begin
        @(negedge clk);
        a = ma[o*beats+b]; w = mw[o*beats+b];
        in_valid = 1; in_first = (b == 0); in_last = (b == beats-1);
      end
    @(negedge clk); in_valid = 0;
    repeat (10) @(negedge clk);
    if (mode == 0) begin
      if (errors == 0 && chk == nout) $display("PASS: %0d activations match", chk);
      else $display("FAIL: errors=%0d outputs=%0d/%0d", errors, chk, nout);
    end else begin
      if (digit == expd) $display("PASS: hardware predicts digit %0d (expected %0d)", digit, expd);
      else $display("FAIL: predicted %0d expected %0d", digit, expd);
    end
    $finish;
  end
endmodule
