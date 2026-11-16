// int32 sum -> +bias -> ReLU -> (x*mult + 32768) >> 16 -> clamp 0..127
module postproc (
  input  clk, rst,
  input  in_valid,
  input  signed [31:0] sum, bias,
  input  [15:0] mult,
  output reg out_valid,
  output reg [7:0] out
);
  reg v1; reg [31:0] relu;
  wire signed [32:0] acc = sum + bias;
  always @(posedge clk) begin
    v1   <= rst ? 1'b0 : in_valid;
    relu <= acc[32] ? 32'd0 : acc[31:0];
  end
  wire [47:0] prod = relu * mult + 48'd32768;
  wire [31:0] r    = prod[47:16];
  always @(posedge clk) begin
    out_valid <= rst ? 1'b0 : v1;
    out       <= (r > 127) ? 8'd127 : r[7:0];
  end
endmodule
