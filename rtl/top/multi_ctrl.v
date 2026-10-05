// Behavioral multi-network controller: 4 tiles, per-output EDF dispatch.
// Job A = LeNet L1 (tb/L1_*.mem), Job B = SmallCNN S2 (tb/S2_*.mem).
// SPLIT=0: dynamic EDF. SPLIT=k: tiles <k serve A only, the rest serve B only.
module multi_ctrl #(
  parameter ARR_A = 500, DL_A = 3000, ARR_B = 0, DL_B = 4000, SPLIT = 0,
  parameter NA = 1024, BA = 10, NB = 256, BB = 18)(
  input clk, rst,
  output reg [3:0]   res_valid,
  output reg [47:0]  res_tag,      // per tile: {job, 11-bit output index}
  output reg [127:0] res_val
);
  reg [127:0] aA [0:NA*BA-1]; reg [127:0] wA [0:NA*BA-1];
  reg [127:0] aB [0:NB*BB-1]; reg [127:0] wB [0:NB*BB-1];
  initial begin
    $readmemh("tb/L1_a.mem", aA); $readmemh("tb/L1_w.mem", wA);
    $readmemh("tb/S2_a.mem", aB); $readmemh("tb/S2_w.mem", wB);
  end

  reg [3:0] t_valid, t_first, t_last;
  reg [511:0] t_a, t_w;
  wire [3:0] o_valid; wire [127:0] o_sum;
  genvar g;
  generate for (g = 0; g < 4; g = g + 1) begin : tl
    tile u(.clk(clk), .rst(rst), .in_valid(t_valid[g]), .in_first(t_first[g]),
           .in_last(t_last[g]), .a(t_a[g*128 +: 128]), .w(t_w[g*128 +: 128]),
           .out_valid(o_valid[g]), .out_sum(o_sum[g*32 +: 32]));
  end endgenerate

  // dispatcher state
  reg        busy [0:3];
  reg        cjob [0:3];
  integer    cidx [0:3], cbeat [0:3], wp [0:3], rp [0:3];
  reg [11:0] tagq [0:31];
  integer t, nb, now, nextA, nextB;
  reg availA, availB, pickA, tj;
  reg [10:0] tidx;

  always @(posedge clk) begin
    if (rst) begin
      now = 0; nextA = 0; nextB = 0;
      for (t = 0; t < 4; t = t + 1) begin
        busy[t] = 0; cjob[t] = 0; cidx[t] = 0; cbeat[t] = 0; wp[t] = 0;
      end
      t_valid <= 0; t_first <= 0; t_last <= 0; t_a <= 0; t_w <= 0;
    end else begin
      t_valid <= 0; t_first <= 0; t_last <= 0;
      for (t = 0; t < 4; t = t + 1) begin
        if (!busy[t]) begin                       // pick next output (EDF)
          availA = (now >= ARR_A) && (nextA < NA);
          availB = (now >= ARR_B) && (nextB < NB);
          if (SPLIT != 0) begin
            if (t < SPLIT) availB = 0; else availA = 0;
          end
          if (availA && availB) pickA = (ARR_A + DL_A <= ARR_B + DL_B);
          else                  pickA = availA;
          if (availA || availB) begin
            busy[t] = 1; cbeat[t] = 0;
            if (pickA) begin cjob[t] = 0; cidx[t] = nextA; nextA = nextA + 1; end
            else       begin cjob[t] = 1; cidx[t] = nextB; nextB = nextB + 1; end
            tj = cjob[t]; tidx = cidx[t];
            tagq[t*8 + (wp[t] % 8)] = {tj, tidx};
            wp[t] = wp[t] + 1;
          end
        end
        if (busy[t]) begin                        // issue one beat
          nb = cjob[t] ? BB : BA;
          t_valid[t] <= 1;
          t_first[t] <= (cbeat[t] == 0);
          t_last[t]  <= (cbeat[t] == nb - 1);
          if (cjob[t]) begin
            t_a[t*128 +: 128] <= aB[cidx[t]*BB + cbeat[t]];
            t_w[t*128 +: 128] <= wB[cidx[t]*BB + cbeat[t]];
          end else begin
            t_a[t*128 +: 128] <= aA[cidx[t]*BA + cbeat[t]];
            t_w[t*128 +: 128] <= wA[cidx[t]*BA + cbeat[t]];
          end
          if (cbeat[t] == nb - 1) busy[t] = 0; else cbeat[t] = cbeat[t] + 1;
        end
      end
      now = now + 1;
    end
  end

  // results come back in order per tile, so a small tag FIFO identifies them
  always @(posedge clk) begin
    if (rst) begin
      for (t = 0; t < 4; t = t + 1) rp[t] = 0;
      res_valid <= 0; res_tag <= 0; res_val <= 0;
    end else begin
      res_valid <= 0;
      for (t = 0; t < 4; t = t + 1) if (o_valid[t]) begin
        res_valid[t]       <= 1;
        res_tag[t*12 +: 12] <= tagq[t*8 + (rp[t] % 8)];
        res_val[t*32 +: 32] <= o_sum[t*32 +: 32];
        rp[t] = rp[t] + 1;
      end
    end
  end
endmodule
