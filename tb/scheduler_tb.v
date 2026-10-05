module scheduler_tb #(parameter P0 = 12000, S0 = 0);
  reg clk = 0, rst = 1; reg [1:0] arrive = 0;
  wire [1:0] done, miss; wire [31:0] lat0, lat1, drop0, drop1; wire [2:0] g0, g1;
  scheduler #(.STATIC0(S0)) dut(.clk(clk), .rst(rst), .arrive(arrive), .done(done), .miss(miss),
                .lat0(lat0), .lat1(lat1), .drop0(drop0), .drop1(drop1), .g0(g0), .g1(g1));
  always #5 clk = ~clk;

  integer cyc = 0, n0 = 0, n1 = 0, m0 = 0, m1 = 0;
  integer s0 = 0, s1 = 0, x0 = 0, x1 = 0;

  always @(negedge clk) if (!rst) begin
    arrive[0] = (cyc % P0 == 0) && (cyc / P0 < 33);
    arrive[1] = (cyc % 100000 == 0) && (cyc / 100000 < 4);
    cyc = cyc + 1;
  end

  always @(posedge clk) begin
    if (done[0]) begin n0=n0+1; s0=s0+lat0; if (lat0>x0) x0=lat0; m0=m0+miss[0]; end
    if (done[1]) begin n1=n1+1; s1=s1+lat1; if (lat1>x1) x1=lat1; m1=m1+miss[1]; end
  end

  initial begin
    repeat (3) @(negedge clk); rst = 0;
    while (!(n0 + drop0 == 33 && n1 + drop1 == 4) && cyc < 1000000) @(negedge clk);
    $display("RTL EDF  makespan=%0d cycles  dropped: lenet=%0d smallcnn=%0d", cyc, drop0, drop1);
    $display("  lenet    avg latency=%0d max=%0d misses=%0d/%0d", s0/n0, x0, m0, n0);
    $display("  smallcnn avg latency=%0d max=%0d misses=%0d/%0d", s1/n1, x1, m1, n1);
    $finish;
  end
endmodule
