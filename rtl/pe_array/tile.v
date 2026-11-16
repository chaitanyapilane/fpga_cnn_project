module tile #(parameter N = 16)(
    input  clk, rst,
    input  in_valid, in_first, in_last,
    input  [N*8-1:0] a,
    input  [N*8-1:0] w,
    output reg out_valid,
    output reg signed [31:0] out_sum
);

    // Stages 1–3: input, multiplier and output registers for each DSP.
    wire signed [15:0] product [0:N-1];
    genvar lane;
    generate
        for (lane = 0; lane < N; lane = lane + 1) begin : mul
            reg signed [7:0] a_q, w_q;
            (* use_dsp = "yes" *) reg signed [15:0] m_q;
            reg signed [15:0] p_q;

            always @(posedge clk) begin
                a_q <= $signed(a[8*lane +: 8]);
                w_q <= $signed(w[8*lane +: 8]);
                m_q <= a_q * w_q;
                p_q <= m_q;
            end

            assign product[lane] = p_q;
        end
    endgenerate

    // Stage 4: each registered group contains four signed products.
    wire signed [16:0] pair_sum [0:7];
    (* use_dsp = "no" *) reg signed [17:0] group_sum [0:3];

    genvar pair_idx, group_idx;
    generate
        for (pair_idx = 0; pair_idx < 8; pair_idx = pair_idx + 1) begin : pairs
            assign pair_sum[pair_idx] =
                product[2*pair_idx] + product[2*pair_idx+1];
        end

        for (group_idx = 0; group_idx < 4; group_idx = group_idx + 1) begin : groups
            always @(posedge clk)
                group_sum[group_idx] <=
                    pair_sum[2*group_idx] + pair_sum[2*group_idx+1];
        end
    endgenerate

    // Stage 5: combine the four groups into one signed 16-lane sum.
    wire signed [18:0] lower_sum = group_sum[0] + group_sum[1];
    wire signed [18:0] upper_sum = group_sum[2] + group_sum[3];
    (* use_dsp = "no" *) reg signed [19:0] beat_sum;

    always @(posedge clk)
        beat_sum <= lower_sum + upper_sum;

    // Carry the control bits alongside the five data stages.
    reg [4:0] valid_pipe, first_pipe, last_pipe;
    always @(posedge clk) begin
        if (rst) begin
            valid_pipe <= 5'b0;
            first_pipe <= 5'b0;
            last_pipe  <= 5'b0;
        end else begin
            valid_pipe <= {valid_pipe[3:0], in_valid};
            first_pipe <= {first_pipe[3:0], in_first};
            last_pipe  <= {last_pipe[3:0],  in_last};
        end
    end

    // Stage 6: first starts a new accumulation; last emits its result.
    reg signed [31:0] acc;
    wire signed [31:0] beat_ext = {{12{beat_sum[19]}}, beat_sum};
    wire signed [31:0] next_acc =
        first_pipe[4] ? beat_ext : acc + beat_ext;

    always @(posedge clk) begin
        out_valid <= 1'b0;
        if (!rst && valid_pipe[4]) begin
            acc <= next_acc;
            if (last_pipe[4]) begin
                out_sum   <= next_acc;
                out_valid <= 1'b1;
            end
        end
    end

endmodule
