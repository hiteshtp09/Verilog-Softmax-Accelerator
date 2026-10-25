`timescale 1ns/1ps

module softmax #(
    parameter MAX_N = 127
)(
    input wire clk,
    input wire rst,
    input wire start,
    input wire [7:0] n,

    input wire [MAX_N*32-1:0] logits,

    output reg [MAX_N*16-1:0] probs,
    output reg done
);

    reg signed [31:0] x [0:MAX_N-1];
    reg signed [31:0] max_val;

    reg [31:0] exp_val [0:MAX_N-1];
    reg [31:0] sum_exp;

    reg [7:0] idx;
    reg [7:0] count;

    reg [2:0] state;

    localparam IDLE       = 3'd0;
    localparam FIND_MAX   = 3'd1;
    localparam EXP_SUM    = 3'd2;
    localparam NORMALIZE  = 3'd3;
    localparam FINISH     = 3'd4;

    integer i;

    // Approximation of exp(-d) * 32768 for integer d.
    function [31:0] exp_lut;
        input [32:0] d;
        begin
            case (d)
                33'd0:  exp_lut = 32768;
                33'd1:  exp_lut = 12055;
                33'd2:  exp_lut = 4435;
                33'd3:  exp_lut = 1631;
                33'd4:  exp_lut = 600;
                33'd5:  exp_lut = 221;
                33'd6:  exp_lut = 81;
                33'd7:  exp_lut = 30;
                33'd8:  exp_lut = 11;
                33'd9:  exp_lut = 4;
                33'd10: exp_lut = 1;
                33'd11: exp_lut = 1;
                default: exp_lut = 0;
            endcase
        end
    endfunction

    reg [32:0] diff;
    reg [31:0] numerator;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state   <= IDLE;
            done    <= 1'b0;
            idx     <= 0;
            count   <= 0;
            max_val <= 0;
            sum_exp <= 0;
            probs   <= 0;

            for (i = 0; i < MAX_N; i = i + 1) begin
                x[i]       <= 0;
                exp_val[i] <= 0;
            end
        end else begin
            case (state)

                IDLE: begin
                    done <= 1'b0;

                    if (start) begin
                        if (n == 0 || n > MAX_N) begin
                            probs <= 0;
                            done  <= 1'b1;
                        end else begin
                            count   <= n;
                            idx     <= 0;
                            max_val <= $signed(logits[31:0]);
                            sum_exp <= 0;
                            probs   <= 0;

                            for (i = 0; i < MAX_N; i = i + 1) begin
                                if (i < n)
                                    x[i] <= $signed(
                                        logits[i*32 +: 32]
                                    );
                                else
                                    x[i] <= 0;
                            end

                            state <= FIND_MAX;
                        end
                    end
                end

                FIND_MAX: begin
                    if ($signed(x[idx]) > $signed(max_val))
                        max_val <= x[idx];

                    if (idx == count - 1) begin
                        idx   <= 0;
                        state <= EXP_SUM;
                    end else begin
                        idx <= idx + 1'b1;
                    end
                end

                EXP_SUM: begin
                    // Difference is max_val - x[idx].
                    // The extra sign bits prevent overflow.
                    diff = $signed({max_val[31], max_val})
                         - $signed({x[idx][31], x[idx]});

                    exp_val[idx] <= exp_lut(diff);
                    sum_exp <= sum_exp + exp_lut(diff);

                    if (idx == count - 1) begin
                        idx   <= 0;
                        state <= NORMALIZE;
                    end else begin
                        idx <= idx + 1'b1;
                    end
                end

                NORMALIZE: begin
                    if (sum_exp != 0) begin
                        numerator =
                            exp_val[idx] * 32'd65535
                            + (sum_exp >> 1);

                        probs[idx*16 +: 16] <=
                            numerator / sum_exp;
                    end else begin
                        probs[idx*16 +: 16] <= 0;
                    end

                    if (idx == count - 1) begin
                        state <= FINISH;
                    end else begin
                        idx <= idx + 1'b1;
                    end
                end

                FINISH: begin
                    done  <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done  <= 1'b0;
                end

            endcase
        end
    end

endmodule
