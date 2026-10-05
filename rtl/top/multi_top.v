module multi_top #(
  parameter T = 4, ARR_A = 500, DL_A = 3000, ARR_B = 0, DL_B = 4000, SPLIT = 0,
  parameter NA = 1024, BA = 10, NB = 256, BB = 18)(
  input  clk, rst,
  output [T-1:0]     m_job,
  output [T*14-1:0]  m_addr,
  input  [T*128-1:0] m_a, m_w,
  output [T-1:0]     res_valid,
  output [T*12-1:0]  res_tag,
  output [T*32-1:0]  res_val
);
  reg [31:0] now;
  reg [10:0] nextA, nextB;
  reg [T-1:0]    busy, cjob;
  reg [T*11-1:0] cidx;
  reg [T*5-1:0]  cbeat;

  reg [T-1:0]    take, tjob;
  reg [T*11-1:0] tidx;
  reg [10:0] nA, nB;
  reg availA, availB, pickA, can;
  integer t;
  always @* begin
    nA = nextA; nB = nextB; take = 0; tjob = 0; tidx = 0;
    for (t = 0; t < T; t = t + 1) begin
      can = !busy[t] || (cbeat[t*5 +: 5] == (cjob[t] ? BB-1 : BA-1));
      availA = (now >= ARR_A) && (nA < NA);
      availB = (now >= ARR_B) && (nB < NB);
      if (SPLIT != 0) begin
        if (t < SPLIT) availB = 0; else availA = 0;
      end
      if (availA && availB) pickA = (ARR_A + DL_A <= ARR_B + DL_B);
      else                  pickA = availA;
      if (can && (availA || availB)) begin
        take[t] = 1;
        if (pickA) begin tjob[t] = 0; tidx[t*11 +: 11] = nA; nA = nA + 1; end
        else       begin tjob[t] = 1; tidx[t*11 +: 11] = nB; nB = nB + 1; end
      end
    end
  end

  always @(posedge clk) begin
    if (rst) begin
      now <= 0; nextA <= 0; nextB <= 0;
      busy <= 0; cjob <= 0; cidx <= 0; cbeat <= 0;
    end else begin
      now <= now + 1; nextA <= nA; nextB <= nB;
      for (t = 0; t < T; t = t + 1) begin
        if (take[t]) begin
          busy[t] <= 1; cjob[t] <= tjob[t];
          cidx[t*11 +: 11] <= tidx[t*11 +: 11]; cbeat[t*5 +: 5] <= 0;
        end else if (busy[t]) begin
          if (cbeat[t*5 +: 5] == (cjob[t] ? BB-1 : BA-1)) busy[t] <= 0;
          else cbeat[t*5 +: 5] <= cbeat[t*5 +: 5] + 1;
        end
      end
    end
  end

  wire [T-1:0]    o_valid;
  wire [T*32-1:0] o_sum;
  genvar g;
  generate for (g = 0; g < T; g = g + 1) begin : tl
    wire [4:0]  bt = cbeat[g*5 +: 5];
    wire        j  = cjob[g];
    wire [10:0] ix = cidx[g*11 +: 11];
    assign m_job[g]           = j;
    assign m_addr[g*14 +: 14] = j ? (ix * BB + bt) : (ix * BA + bt);

    reg v_d, f_d, l_d;
    always @(posedge clk) begin
      v_d <= rst ? 1'b0 : busy[g];
      f_d <= (bt == 0);
      l_d <= (bt == (j ? BB-1 : BA-1));
    end

    tile u (.clk(clk), .rst(rst), .in_valid(v_d), .in_first(f_d), .in_last(l_d),
            .a(m_a[g*128 +: 128]), .w(m_w[g*128 +: 128]),
            .out_valid(o_valid[g]), .out_sum(o_sum[g*32 +: 32]));

    reg [11:0] tq [0:7];
    reg [2:0]  wp, rp;
    always @(posedge clk) begin
      if (rst) begin wp <= 0; rp <= 0; end
      else begin
        if (take[g])    begin tq[wp] <= {tjob[g], tidx[g*11 +: 11]}; wp <= wp + 1; end
        if (o_valid[g]) rp <= rp + 1;
      end
    end

    reg rv; reg [11:0] rtag; reg [31:0] rval;
    always @(posedge clk) begin
      rv   <= !rst && o_valid[g];
      rtag <= tq[rp];
      rval <= o_sum[g*32 +: 32];
    end
    assign res_valid[g]        = rv;
    assign res_tag[g*12 +: 12] = rtag;
    assign res_val[g*32 +: 32] = rval;
  end endgenerate
endmodule
