module pool2x2 (
  input clk, rst, in_valid,
  input [7:0] a, b, c, d,
  output reg out_valid,
  output reg [7:0] out
);
  wire [7:0] m1 = (a > b) ? a : b;
  wire [7:0] m2 = (c > d) ? c : d;
  always @(posedge clk) begin
    out_valid <= rst ? 1'b0 : in_valid;
    out <= (m1 > m2) ? m1 : m2;
  end
endmodule
