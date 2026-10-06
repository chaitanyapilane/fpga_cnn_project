module chain2_tb;
  reg clk = 0, rst = 1, in_valid = 0, in_first = 0, in_last = 0;
  reg [127:0] a = 0, w = 0;
  wire t_valid; wire signed [31:0] t_sum;
  tile u_t(.clk(clk), .rst(rst), .in_valid(in_valid), .in_first(in_first), .in_last(in_last),
           .a(a), .w(w), .out_valid(t_valid), .out_sum(t_sum));

  reg [31:0] bias_tab [0:15]; reg [15:0] mult_m [0:0];
  integer nsum = 0;
  always @(posedge clk) if (t_valid) nsum <= nsum + 1;
  wire signed [31:0] bias = bias_tab[nsum / 64];

  wire p_valid; wire [7:0] p_out;
  postproc u_p(.clk(clk), .rst(rst), .in_valid(t_valid), .sum(t_sum), .bias(bias),
               .mult(mult_m[0]), .out_valid(p_valid), .out(p_out));
  wire q_valid; wire [7:0] q_out;
  linebuf_pool #(.W(8)) u_q(.clk(clk), .rst(rst), .in_valid(p_valid), .din(p_out),
                            .out_valid(q_valid), .dout(q_out));
  always #5 clk = ~clk;

  reg [127:0] ma [0:10239]; reg [127:0] mw [0:10239]; reg [7:0] e [0:255];
  integer o, b, chk = 0, errors = 0;
  always @(posedge clk) if (q_valid) begin
    if (q_out !== e[chk]) begin errors = errors + 1;
      if (errors < 10) $display("MISMATCH %0d: got %0d exp %0d", chk, q_out, e[chk]); end
    chk = chk + 1;
  end

  initial begin
    $readmemh("tb/c2_bias.mem", bias_tab); $readmemh("tb/c2_mult.mem", mult_m);
    $readmemh("tb/L1_a.mem", ma); $readmemh("tb/L1_w.mem", mw); $readmemh("tb/pool2_exp.mem", e);
    repeat (3) @(negedge clk); rst = 0;
    for (o = 0; o < 1024; o = o + 1)
      for (b = 0; b < 10; b = b + 1) begin
        @(negedge clk);
        a = ma[10*o+b]; w = mw[10*o+b];
        in_valid = 1; in_first = (b == 0); in_last = (b == 9);
      end
    @(negedge clk); in_valid = 0;
    repeat (10) @(negedge clk);
    if (errors == 0 && chk == 256) $display("PASS: conv2 chain: %0d activations match", chk);
    else $display("FAIL: errors=%0d outputs=%0d", errors, chk);
    $finish;
  end
endmodule
