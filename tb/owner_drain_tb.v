module owner_drain_tb;
  reg clk = 0, rst = 1;
  always #5 clk = ~clk;

  reg valid = 0, change = 0;
  reg [1:0] requested_owner = 0;
  wire result_valid, idle;
  wire [1:0] owner;
  wire [31:0] result;

  pe_array #(.T(1), .N(16)) dut (
    .clk(clk), .rst(rst),
    .in_valid(valid), .in_first(valid), .in_last(valid),
    .a({16{8'd1}}), .w({16{8'd1}}),
    .set_owner(change), .new_owner(requested_owner),
    .out_valid(result_valid), .out_sum(result),
    .out_owner(owner), .idle(idle)
  );

  initial begin
    repeat (3) @(negedge clk);
    rst = 0;

    // Assign owner 1 while the tile is idle.
    change = 1; requested_owner = 1;
    @(negedge clk);
    if (owner !== 2'd1) $fatal(1, "Initial owner assignment failed");

    // Issue one complete dot product for owner 1.
    change = 0; valid = 1;
    @(negedge clk);
    valid = 0;

    // Keep requesting owner 2 while owner 1's result drains.
    change = 1; requested_owner = 2;
    repeat (12) begin
      @(negedge clk);
      if (result_valid === 1'b1) begin
        if (result !== 32'd16 || owner !== 2'd1)
          $fatal(1, "Result should be 16 for owner 1; got %0d for owner %0d",
                 result, owner);
        repeat (3) @(negedge clk);
        if (owner !== 2'd2) $fatal(1, "Owner did not change after drain");
        $display("PASS: owner held through final result, then reassigned");
        $finish;
      end
    end
    $fatal(1, "Timed out waiting for tile result");
  end
endmodule
