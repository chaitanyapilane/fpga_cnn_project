module postproc_tb;
  reg clk = 0, rst = 1, in_valid = 0;
  reg signed [31:0] sum = 0, bias = 0;
  wire out_valid; wire [7:0] out;
  postproc dut(.clk(clk), .rst(rst), .in_valid(in_valid), .sum(sum), .bias(bias),
               .mult(16'd72), .out_valid(out_valid), .out(out));
  always #5 clk = ~clk;

  reg [31:0] raw [0:3455]; reg [7:0] exp [0:3455];
  integer b [0:5];
  integer i, chk = 0, errors = 0;

  always @(posedge clk) if (out_valid) begin
    if (out !== exp[chk]) begin
      errors = errors + 1;
      if (errors < 10) $display("MISMATCH %0d: got %0d expected %0d", chk, out, exp[chk]);
    end
    chk = chk + 1;
  end

  initial begin
    b[0] = -3272; b[1] = 3974; b[2] = -137; b[3] = -81; b[4] = 4549; b[5] = -251;
    $readmemh("tb/L0_exp.mem", raw); $readmemh("tb/pp_exp.mem", exp);
    repeat (3) @(negedge clk); rst = 0;
    for (i = 0; i < 3456; i = i + 1) begin
      @(negedge clk); sum = raw[i]; bias = b[i / 576]; in_valid = 1;
    end
    @(negedge clk); in_valid = 0;
    repeat (5) @(negedge clk);
    if (errors == 0 && chk == 3456) $display("PASS: %0d post-processed outputs match", chk);
    else $display("FAIL: errors=%0d outputs=%0d", errors, chk);
    $finish;
  end
endmodule
