module pe_array_tb;
  reg clk = 0, rst = 1;
  reg [3:0] in_valid = 0, in_first = 0, in_last = 0, set_owner = 0;
  reg [511:0] a = 0, w = 0;
  reg [7:0] new_owner = 0;
  wire [3:0] out_valid, idle;
  wire [127:0] out_sum; wire [7:0] out_owner;
  pe_array dut(.clk(clk), .rst(rst), .in_valid(in_valid), .in_first(in_first),
    .in_last(in_last), .a(a), .w(w), .set_owner(set_owner), .new_owner(new_owner),
    .out_valid(out_valid), .out_sum(out_sum), .out_owner(out_owner), .idle(idle));
  always #5 clk = ~clk;

  integer expv [0:3], got [0:3], own [0:3], seen [0:3];
  integer t, k, b, errors = 0;
  reg signed [7:0] x, y;

  always @(posedge clk) for (t = 0; t < 4; t = t + 1) if (out_valid[t]) begin
    got[t] = $signed(out_sum[t*32 +: 32]); own[t] = out_owner[t*2 +: 2]; seen[t] = 1;
  end

  initial begin
    $dumpfile("pe_array.vcd"); $dumpvars(0, pe_array_tb);
    for (t = 0; t < 4; t = t + 1) begin expv[t] = 0; seen[t] = 0; end
    repeat (3) @(negedge clk); rst = 0;
    @(negedge clk); set_owner = 4'b1111; new_owner = {2'd2, 2'd2, 2'd1, 2'd1};
    @(negedge clk); set_owner = 0;
    if (idle !== 4'b1111) begin errors = errors + 1; $display("FAIL: tiles not idle"); end
    for (b = 0; b < 4; b = b + 1) begin
      @(negedge clk);
      for (t = 0; t < 4; t = t + 1) for (k = 0; k < 16; k = k + 1) begin
        x = $random; y = $random;
        a[(t*16+k)*8 +: 8] = x; w[(t*16+k)*8 +: 8] = y;
        expv[t] = expv[t] + x * y;
      end
      in_valid = 4'b1111;
      in_first = (b == 0) ? 4'b1111 : 4'b0000;
      in_last  = (b == 3) ? 4'b1111 : 4'b0000;
      if (b == 2) begin set_owner = 4'b0001; new_owner[1:0] = 2'd3; end
      else set_owner = 0;
    end
    @(negedge clk); in_valid = 0; set_owner = 0;
    repeat (6) @(negedge clk);
    for (t = 0; t < 4; t = t + 1) begin
      if (!seen[t] || got[t] !== expv[t]) begin
        errors = errors + 1; $display("MISMATCH tile %0d: got %0d expected %0d", t, got[t], expv[t]);
      end
      if (own[t] !== ((t < 2) ? 1 : 2)) begin
        errors = errors + 1; $display("OWNER tile %0d: got %0d", t, own[t]);
      end
    end
    if (errors == 0) $display("PASS: 4 tiles, results and owner tags correct, busy reassign rejected");
    else $display("FAIL: %0d errors", errors);
    $finish;
  end
endmodule
