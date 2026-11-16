// Nexys 4 demo: multi_top + per-tile BRAM copies + hardware result checker.
module demo_top #(parameter SPLIT = 0)(
  input clk, cpu_resetn, btnc,
  output [7:0] led
);
  localparam NA = 128, BA = 10, NB = 32, BB = 18;
  localparam ARR_A = 50, DL_A = 400, ARR_B = 0, DL_B = 600;

  reg [3:0] rsh = 4'hF;
  always @(posedge clk) rsh <= {rsh[2:0], (~cpu_resetn) | btnc};
  wire rst = rsh[3];

  wire [3:0] m_job, rv; wire [55:0] m_addr; wire [47:0] rtag; wire [127:0] rval;
  wire [511:0] m_a, m_w; wire [127:0] expv;

  multi_top #(.SPLIT(SPLIT), .ARR_A(ARR_A), .DL_A(DL_A), .ARR_B(ARR_B), .DL_B(DL_B),
              .NA(NA), .BA(BA), .NB(NB), .BB(BB))
    u (.clk(clk), .rst(rst), .m_job(m_job), .m_addr(m_addr), .m_a(m_a), .m_w(m_w),
       .res_valid(rv), .res_tag(rtag), .res_val(rval));

  genvar g;
  generate for (g = 0; g < 4; g = g + 1) begin : mem
    reg [127:0] aA [0:NA*BA-1]; reg [127:0] wA [0:NA*BA-1];
    reg [127:0] aB [0:NB*BB-1]; reg [127:0] wB [0:NB*BB-1];
    reg [31:0]  eA [0:NA-1];    reg [31:0]  eB [0:NB-1];
    initial begin
      $readmemh("tb/demo_A_a.mem", aA); $readmemh("tb/demo_A_w.mem", wA);
      $readmemh("tb/demo_B_a.mem", aB); $readmemh("tb/demo_B_w.mem", wB);
      $readmemh("tb/demo_A_exp.mem", eA); $readmemh("tb/demo_B_exp.mem", eB);
    end
    wire [13:0] ad = m_addr[g*14 +: 14];
    reg [127:0] qaA, qwA, qaB, qwB; reg jd;
    always @(posedge clk) begin
      qaA <= aA[ad]; qwA <= wA[ad];
      qaB <= aB[ad]; qwB <= wB[ad];
      jd  <= m_job[g];
    end
    assign m_a[g*128 +: 128] = jd ? qaB : qaA;
    assign m_w[g*128 +: 128] = jd ? qwB : qwA;
    wire [11:0] tg = rtag[g*12 +: 12];
    assign expv[g*32 +: 32] = tg[11] ? eB[tg[4:0]] : eA[tg[6:0]];
  end endgenerate

  // ---- checker ----
  reg [15:0] cntA, cntB, errs;
  reg [31:0] cyc, endA, endB;
  wire doneA = (cntA == NA), doneB = (cntB == NB);
  integer t; reg [15:0] ca, cb, er;
  always @(posedge clk) begin
    if (rst) begin cntA <= 0; cntB <= 0; errs <= 0; cyc <= 0; endA <= 0; endB <= 0; end
    else begin
      if (!(doneA && doneB)) cyc <= cyc + 1;
      ca = cntA; cb = cntB; er = errs;
      for (t = 0; t < 4; t = t + 1) if (rv[t]) begin
        if (rtag[t*12 + 11]) cb = cb + 1; else ca = ca + 1;
        if (rval[t*32 +: 32] !== expv[t*32 +: 32]) er = er + 1;
      end
      cntA <= ca; cntB <= cb; errs <= er;
      if (ca == NA && cntA != NA) endA <= cyc;
      if (cb == NB && cntB != NB) endB <= cyc;
    end
  end

  wire metA = doneA && (endA - ARR_A <= DL_A);
  wire metB = doneB && (endB - ARR_B <= DL_B);
  assign led = {2'b0, (errs != 0), metB, metA, doneA & doneB & (errs == 0), doneB, doneA};
endmodule
