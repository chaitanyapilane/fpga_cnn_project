// One 64-beat job: check the last address, output tag and signed dot product.
module multi_top_long_beat_tb;
  reg clk = 0, rst = 1;
  always #5 clk = ~clk;
  wire job, valid;
  wire [13:0] addr;
  wire [11:0] tag;
  wire [31:0] val;
  reg [127:0] a, w;
  multi_top #(.T(1), .NA(0), .NB(1), .BB(64))
    dut(.clk(clk), .rst(rst), .m_job(job), .m_addr(addr),
        .m_a(a), .m_w(w), .res_valid(valid), .res_tag(tag), .res_val(val));
  reg saw_last = 0;
  always @(posedge clk) begin
    a <= {16{addr[7:0]}};
    w <= {16{8'hff}};
    if (!rst && job && addr == 63) saw_last <= 1;
  end
  integer results = 0;
  initial begin
    repeat (3) @(negedge clk);
    rst = 0;
    repeat (100) begin
      @(negedge clk);
      if (valid) begin
        if (!saw_last || tag !== 12'h800 || $signed(val) !== -32'sd32256)
          $fatal(1, "64-beat result failed: tag=%h value=%d", tag, $signed(val));
        results = results + 1;
      end
    end
    if (results != 1) $fatal(1, "Expected one 64-beat result, got %0d", results);
    $display("PASS: 64-beat job");
    $finish;
  end
endmodule
