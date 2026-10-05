// 4 tiles x 16 INT8 MACs. Per-tile owner tag, changeable only when idle.
module pe_array #(parameter T = 4, N = 16)(
  input  clk, rst,
  input  [T-1:0]       in_valid, in_first, in_last,
  input  [T*N*8-1:0]   a, w,
  input  [T-1:0]       set_owner,     // request owner change per tile
  input  [T*2-1:0]     new_owner,
  output [T-1:0]       out_valid,
  output [T*32-1:0]    out_sum,
  output [T*2-1:0]     out_owner,
  output [T-1:0]       idle
);
  reg [T*2-1:0] owner;
  assign out_owner = owner;

  genvar g;
  generate for (g = 0; g < T; g = g + 1) begin : t
    reg [2:0] pipe;                              // in-flight beats
    always @(posedge clk)
      if (rst) pipe <= 3'b0;
      else     pipe <= {pipe[1:0], in_valid[g]};
    assign idle[g] = ~(in_valid[g] | (|pipe));

    always @(posedge clk)
      if (rst) owner[g*2 +: 2] <= 2'd0;
      else if (set_owner[g] && idle[g]) owner[g*2 +: 2] <= new_owner[g*2 +: 2];

    tile #(.N(N)) u (
      .clk(clk), .rst(rst),
      .in_valid(in_valid[g]), .in_first(in_first[g]), .in_last(in_last[g]),
      .a(a[g*N*8 +: N*8]), .w(w[g*N*8 +: N*8]),
      .out_valid(out_valid[g]), .out_sum(out_sum[g*32 +: 32]));
  end endgenerate
endmodule
