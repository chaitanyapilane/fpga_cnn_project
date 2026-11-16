module chain_tb;
  reg clk = 0, rst = 1, in_valid = 0, in_first = 0, in_last = 0;
  reg [127:0] a = 0, w = 0;
  wire t_valid; wire signed [31:0] t_sum;
  tile u_t(.clk(clk), .rst(rst), .in_valid(in_valid), .in_first(in_first), .in_last(in_last),
           .a(a), .w(w), .out_valid(t_valid), .out_sum(t_sum));

  integer bias_tab [0:5];
  integer nsum = 0;
  reg signed [31:0] bias;
  always @(posedge clk) if (t_valid) nsum <= nsum + 1;
  always @* bias = bias_tab[nsum / 576];

  wire p_valid; wire [7:0] p_out;
  postproc u_p(.clk(clk), .rst(rst), .in_valid(t_valid), .sum(t_sum), .bias(bias),
               .mult(16'd72), .out_valid(p_valid), .out(p_out));
  wire q_valid; wire [7:0] q_out;
  linebuf_pool #(.W(24)) u_q(.clk(clk), .rst(rst), .in_valid(p_valid), .din(p_out),
                             .out_valid(q_valid), .dout(q_out));
  always #5 clk = ~clk;

  reg [127:0] ma [0:6911]; reg [127:0] mw [0:6911]; reg [7:0] e [0:863];
  integer o, b, chk = 0, errors = 0;
  always @(posedge clk) if (q_valid) begin
    if (q_out !== e[chk]) begin errors = errors + 1;
      if (errors < 10) $display("MISMATCH %0d: got %0d exp %0d", chk, q_out, e[chk]); end
    chk = chk + 1;
  end

  initial begin
    bias_tab[0] = -3272; bias_tab[1] = 3974; bias_tab[2] = -137;
    bias_tab[3] = -81;   bias_tab[4] = 4549; bias_tab[5] = -251;
    $readmemh("tb/L0_a.mem", ma); $readmemh("tb/L0_w.mem", mw); $readmemh("tb/pool_exp.mem", e);
    repeat (3) @(negedge clk); rst = 0;
    for (o = 0; o < 3456; o = o + 1)
      for (b = 0; b < 2; b = b + 1) begin
        @(negedge clk);
        a = ma[2*o+b]; w = mw[2*o+b];
        in_valid = 1; in_first = (b == 0); in_last = (b == 1);
      end
    @(negedge clk); in_valid = 0;
    repeat (10) @(negedge clk);
    if (errors == 0 && chk == 864) $display("PASS: conv1 -> bias/ReLU/requant -> pool: %0d activations match", chk);
    else $display("FAIL: errors=%0d outputs=%0d", errors, chk);
    $finish;
  end
endmodule
