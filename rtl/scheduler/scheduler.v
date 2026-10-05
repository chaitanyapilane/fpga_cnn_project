// Strict-EDF tile scheduler. Job 0 = LeNet, job 1 = SmallCNN.
// Grants are re-decided only at chunk boundaries; a grant takes effect 1 cycle after the decision.
module scheduler #(parameter T = 4, DL0 = 6000, DL1 = 150000,
                   NCH0 = 37, NCH1 = 344, STATIC0 = 0)(
  input clk, rst,
  input  [1:0] arrive,
  output reg [1:0] done, miss,
  output reg [31:0] lat0, lat1, drop0, drop1,
  output reg [2:0] g0, g1            // tiles granted to each job
);
  reg [15:0] rom0 [0:63];
  reg [15:0] rom1 [0:511];
  initial begin
    $readmemh("rtl/scheduler/chunks_lenet.mem", rom0);
    $readmemh("rtl/scheduler/chunks_smallcnn.mem", rom1);
  end

  reg [31:0] now;
  reg v0, v1;
  reg [31:0] dl0, dl1, arr0, arr1;
  reg [9:0]  idx0, idx1;
  reg [15:0] rem0, rem1;

  wire [2:0] free = T - g0 - g1;
  wire wait0 = v0 && (g0 == 0);
  wire wait1 = v1 && (g1 == 0);

  always @(posedge clk) begin
    if (rst) begin
      now <= 0; v0 <= 0; v1 <= 0; g0 <= 0; g1 <= 0;
      done <= 0; miss <= 0; lat0 <= 0; lat1 <= 0; drop0 <= 0; drop1 <= 0;
    end else begin
      now <= now + 1; done <= 0; miss <= 0;

      // progress job 0
      if (v0 && g0 != 0) begin
        if (rem0 <= g0) begin
          g0 <= 0;
          if (idx0 == NCH0-1) begin
            v0 <= 0; done[0] <= 1; lat0 <= now + 1 - arr0; miss[0] <= (now + 1 > dl0);
          end else begin idx0 <= idx0 + 1; rem0 <= rom0[idx0 + 1]; end
        end else rem0 <= rem0 - g0;
      end
      // progress job 1
      if (v1 && g1 != 0) begin
        if (rem1 <= g1) begin
          g1 <= 0;
          if (idx1 == NCH1-1) begin
            v1 <= 0; done[1] <= 1; lat1 <= now + 1 - arr1; miss[1] <= (now + 1 > dl1);
          end else begin idx1 <= idx1 + 1; rem1 <= rom1[idx1 + 1]; end
        end else rem1 <= rem1 - g1;
      end

      // allocation: earliest deadline among waiting jobs takes every free tile
      if (STATIC0 != 0) begin
        // static split: job 0 owns STATIC0 tiles, job 1 owns the rest
        if (wait0) g0 <= STATIC0;
        if (wait1) g1 <= T - STATIC0;
      end else if (free != 0) begin
        if (wait0 && wait1) begin
          if (dl0 <= dl1) g0 <= free; else g1 <= free;
        end else if (wait0) g0 <= free;
        else if (wait1) g1 <= free;
      end

      // arrivals
      if (arrive[0]) begin if (v0) drop0 <= drop0 + 1; else begin v0 <= 1; arr0 <= now; dl0 <= now + DL0; idx0 <= 0; rem0 <= rom0[0]; g0 <= 0; end end
      if (arrive[1]) begin if (v1) drop1 <= drop1 + 1; else begin v1 <= 1; arr1 <= now; dl1 <= now + DL1; idx1 <= 0; rem1 <= rom1[0]; g1 <= 0; end end
    end
  end
endmodule
