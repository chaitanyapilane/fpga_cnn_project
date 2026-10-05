module multi_tb #(parameter SPLIT = 0, ARR_A = 500, DL_A = 3000, ARR_B = 0, DL_B = 4000);
  reg clk = 0, rst = 1;
  wire [3:0] rv; wire [47:0] rt; wire [127:0] rval;
  multi_ctrl #(.SPLIT(SPLIT), .ARR_A(ARR_A), .DL_A(DL_A), .ARR_B(ARR_B), .DL_B(DL_B))
    dut(.clk(clk), .rst(rst), .res_valid(rv), .res_tag(rt), .res_val(rval));
  always #5 clk = ~clk;

  reg [31:0] eA [0:1023]; reg [31:0] eB [0:255];
  reg seenA [0:1023]; reg seenB [0:255];
  integer cyc = 0, cntA = 0, cntB = 0, endA = 0, endB = 0, errors = 0;
  integer t, i, idx; reg [11:0] tg; reg [31:0] v;
  integer missA, missB;

  always @(posedge clk) if (!rst) begin
    for (t = 0; t < 4; t = t + 1) if (rv[t]) begin
      tg = rt[t*12 +: 12]; v = rval[t*32 +: 32]; idx = tg[10:0];
      if (tg[11] == 0) begin
        if (v !== eA[idx] || seenA[idx]) begin
          errors = errors + 1;
          if (errors < 10) $display("BAD lenet out %0d: got %0d exp %0d dup=%0d", idx, $signed(v), $signed(eA[idx]), seenA[idx]);
        end
        seenA[idx] = 1; cntA = cntA + 1; if (cntA == 1024) endA = cyc;
      end else begin
        if (v !== eB[idx] || seenB[idx]) begin
          errors = errors + 1;
          if (errors < 10) $display("BAD smallcnn out %0d: got %0d exp %0d dup=%0d", idx, $signed(v), $signed(eB[idx]), seenB[idx]);
        end
        seenB[idx] = 1; cntB = cntB + 1; if (cntB == 256) endB = cyc;
      end
    end
    cyc = cyc + 1;
  end

  initial begin
    $readmemh("tb/L1_exp.mem", eA); $readmemh("tb/S2_exp.mem", eB);
    for (i = 0; i < 1024; i = i + 1) seenA[i] = 0;
    for (i = 0; i < 256;  i = i + 1) seenB[i] = 0;
    repeat (5) @(negedge clk); rst = 0;
    while (!(cntA == 1024 && cntB == 256) && cyc < 100000) @(negedge clk);
    missA = (cntA < 1024) || (endA - ARR_A > DL_A);
    missB = (cntB < 256)  || (endB - ARR_B > DL_B);
    $display("SPLIT=%0d  makespan=%0d  outputs: lenet %0d/1024, smallcnn %0d/256, errors=%0d",
             SPLIT, cyc, cntA, cntB, errors);
    $display("  lenet    finish=%0d latency=%0d deadline=%0d  %0s", endA, endA - ARR_A, DL_A, missA ? "MISSED" : "met");
    $display("  smallcnn finish=%0d latency=%0d deadline=%0d  %0s", endB, endB - ARR_B, DL_B, missB ? "MISSED" : "met");
    if (errors == 0 && cntA == 1024 && cntB == 256) $display("  PASS: all 1280 outputs bit-exact");
    else $display("  FAIL");
    $finish;
  end
endmodule
