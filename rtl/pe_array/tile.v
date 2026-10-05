// 16-MAC INT8 tile: 16 products -> adder tree -> accumulator.
// in_first clears the accumulator for a new output; in_last emits the result.
module tile #(parameter N = 16)(
  input  clk, rst,
  input  in_valid, in_first, in_last,
  input  [N*8-1:0] a,           // N signed INT8 activations
  input  [N*8-1:0] w,           // N signed INT8 weights
  output reg out_valid,
  output reg signed [31:0] out_sum
);
  // Stage 1: multiply
  reg signed [15:0] p [0:N-1];
  reg v1, f1, l1;
  integer i;
  always @(posedge clk) begin
    for (i = 0; i < N; i = i + 1)
      p[i] <= $signed(a[8*i +: 8]) * $signed(w[8*i +: 8]);
    v1 <= rst ? 1'b0 : in_valid;
    f1 <= in_first;  l1 <= in_last;
  end

  // Stage 2: adder tree
  reg signed [19:0] sum;
  reg v2, f2, l2;
  integer j;
  reg signed [19:0] s;
  always @(posedge clk) begin
    s = 0;
    for (j = 0; j < N; j = j + 1) s = s + p[j];
    sum <= s;
    v2 <= rst ? 1'b0 : v1;
    f2 <= f1;  l2 <= l1;
  end

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
