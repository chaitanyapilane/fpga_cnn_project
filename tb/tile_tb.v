module tile_tb;
  reg clk = 0, rst = 1;
  reg in_valid = 0, in_first = 0, in_last = 0;
  reg [127:0] a = 0, w = 0;
  wire out_valid; wire signed [31:0] out_sum;
  tile dut(.clk(clk), .rst(rst), .in_valid(in_valid), .in_first(in_first),
           .in_last(in_last), .a(a), .w(w), .out_valid(out_valid), .out_sum(out_sum));
  always #5 clk = ~clk;

  integer expv [0:19];
  integer o, b, k, chk = 0, errors = 0;
  reg signed [7:0] x, y;

  always @(posedge clk) if (out_valid) begin
    if (out_sum !== expv[chk]) begin
      errors = errors + 1;
      $display("MISMATCH out %0d: got %0d expected %0d", chk, out_sum, expv[chk]);
    end
    chk = chk + 1;
  end

  initial begin
    $dumpfile("tile.vcd"); $dumpvars(0, tile_tb);
    repeat (3) @(negedge clk); rst = 0;
    for (o = 0; o < 20; o = o + 1) begin
      expv[o] = 0;
      for (b = 0; b < 4; b = b + 1) begin
        @(negedge clk);
        for (k = 0; k < 16; k = k + 1) begin
          x = $random; y = $random;
          a[8*k +: 8] = x; w[8*k +: 8] = y;
          expv[o] = expv[o] + x * y;
        end
        in_valid = 1; in_first = (b == 0); in_last = (b == 3);
      end
    end
    @(negedge clk); in_valid = 0;
    repeat (6) @(negedge clk);
    if (errors == 0 && chk == 20) $display("PASS: %0d outputs match", chk);
    else $display("FAIL: errors=%0d outputs=%0d", errors, chk);
    $finish;
  end
endmodule
