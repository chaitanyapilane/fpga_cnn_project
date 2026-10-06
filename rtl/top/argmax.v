// Streaming argmax over N signed scores; emits the index of the maximum.
module argmax #(parameter N = 10)(
  input clk, rst, in_valid,
  input signed [31:0] score,
  output reg out_valid,
  output reg [3:0] idx
);
  reg signed [31:0] best; reg [3:0] cnt, bidx;
  wire better = (cnt == 0) || (score > best);
  always @(posedge clk) begin
    out_valid <= 1'b0;
    if (rst) cnt <= 0;
    else if (in_valid) begin
      if (better) begin best <= score; bidx <= cnt; end
      if (cnt == N-1) begin
        out_valid <= 1'b1; idx <= better ? cnt : bidx; cnt <= 0;
      end else cnt <= cnt + 1;
    end
  end
endmodule
