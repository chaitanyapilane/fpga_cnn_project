// 16-MAC INT8 tile: multipliers (DSP) -> 4-level pipelined adder tree (LUT) -> accumulator.
// Latency: 6 cycles from first input beat to out_valid.
module tile #(parameter N = 16)(
  input  clk, rst,
  input  in_valid, in_first, in_last,
  input  [N*8-1:0] a,
  input  [N*8-1:0] w,
  output reg out_valid,
  output reg signed [31:0] out_sum
);
  // Stage 1: one multiplier per lane, each with its own register (DSP48)
  wire [N*16-1:0] pflat;
  genvar gi;
  generate for (gi = 0; gi < N; gi = gi + 1) begin : mul
    (* use_dsp = "yes" *) reg signed [15:0] pr;
    always @(posedge clk) pr <= $signed(a[8*gi +: 8]) * $signed(w[8*gi +: 8]);
    assign pflat[16*gi +: 16] = pr;
  end endgenerate

  reg v1, f1, lst1;
  always @(posedge clk) begin
    v1   <= rst ? 1'b0 : in_valid;
    f1   <= in_first;
    lst1 <= in_last;
  end

  // Stage 2: pipelined adder tree, kept in LUT fabric
  (* use_dsp = "no" *) reg signed [16:0] t1 [0:7];
  (* use_dsp = "no" *) reg signed [17:0] t2 [0:3];
  (* use_dsp = "no" *) reg signed [18:0] t3 [0:1];
  (* use_dsp = "no" *) reg signed [19:0] sum;
  reg [3:0] vv, ff, ll;
  integer j;
  always @(posedge clk) begin
    for (j = 0; j < 8; j = j + 1)
      t1[j] <= $signed(pflat[32*j +: 16]) + $signed(pflat[32*j+16 +: 16]);
    for (j = 0; j < 4; j = j + 1) t2[j] <= t1[2*j] + t1[2*j+1];
    for (j = 0; j < 2; j = j + 1) t3[j] <= t2[2*j] + t2[2*j+1];
    sum <= t3[0] + t3[1];
    vv <= {vv[2:0], rst ? 1'b0 : v1};
    ff <= {ff[2:0], f1};
    ll <= {ll[2:0], lst1};
  end
  wire v2 = vv[3], f2 = ff[3], l2 = ll[3];

  // Stage 3: accumulate
  reg signed [31:0] acc;
  wire signed [31:0] nxt = (f2 ? 32'sd0 : acc) + sum;
  always @(posedge clk) begin
    out_valid <= 1'b0;
    if (!rst && v2) begin
      acc <= nxt;
      if (l2) begin out_sum <= nxt; out_valid <= 1'b1; end
    end
  end
endmodule
