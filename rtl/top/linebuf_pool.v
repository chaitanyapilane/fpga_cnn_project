// Streaming 2x2 max-pool for a W-wide feature map (W even), raster order.
module linebuf_pool #(parameter W = 24)(
  input clk, rst, in_valid,
  input [7:0] din,
  output reg out_valid,
  output reg [7:0] dout
);
  reg [7:0] row [0:W-1];     // even-row values
  reg [7:0] pend;            // max of the pair on the odd row
  reg [4:0] col;
  reg       odd;
  wire [7:0] stored = row[col];
  wire [7:0] m = (din > stored) ? din : stored;   // vertical max (odd row)
  always @(posedge clk) begin
    out_valid <= 1'b0;
    if (rst) begin col <= 0; odd <= 0; end
    else if (in_valid) begin
      if (!odd) row[col] <= din;
      else if (col[0] == 0) pend <= m;
      else begin
        dout <= (pend > m) ? pend : m;
        out_valid <= 1'b1;
      end
      if (col == W-1) begin col <= 0; odd <= ~odd; end
      else col <= col + 1;
    end
  end
endmodule
