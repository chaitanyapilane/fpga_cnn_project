module mac #(parameter W=8)(
  input clk, input rst,
  input signed [W-1:0] a, b,
  output reg signed [2*W+7:0] acc
);
  always @(posedge clk)
    if (rst) acc <= 0;
    else acc <= acc + a*b;
endmodule
