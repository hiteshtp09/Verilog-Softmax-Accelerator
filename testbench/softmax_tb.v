`timescale 1ns/1ps

module softmax_tb;

    parameter MAX_N = 127;

    reg clk;
    reg rst;
    reg start;
    reg [7:0] n;

    reg [MAX_N*32-1:0] logits;

    wire [MAX_N*16-1:0] probs;
    wire done;

    integer i;
    integer scan_status;
    integer input_value;
    integer input_n;
    integer probability_sum;

    real probability;

    softmax #(
        .MAX_N(MAX_N)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .n(n),
        .logits(logits),
        .probs(probs),
        .done(done)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst = 1;
        start = 0;
        n = 0;
        logits = 0;

        $dumpfile("softmax.vcd");
        $dumpvars(0, softmax_tb);

        #20;
        rst = 0;

        $display("");
        $display("====================================");
        $display("     N-INPUT SOFTMAX ACCELERATOR");
        $display("====================================");

        $write("Enter number of inputs N (1-%0d): ", MAX_N);
        scan_status = $fscanf(32'h80000000, "%d", input_n);

        if (scan_status != 1 || input_n < 1 || input_n > MAX_N) begin
            $display("Invalid input count.");
            $finish;
        end

        n = input_n;

        for (i = 0; i < input_n; i = i + 1) begin
            $write("Enter logit %0d: ", i);
            scan_status = $fscanf(32'h80000000, "%d", input_value);

            if (scan_status != 1) begin
                $display("Invalid logit.");
                $finish;
            end

            logits[i*32 +: 32] = input_value;
        end

        @(negedge clk);
        start = 1;

        @(negedge clk);
        start = 0;

        wait(done == 1'b1);

        $display("");
        $display("---------- SOFTMAX RESULTS ----------");

        probability_sum = 0;

        for (i = 0; i < input_n; i = i + 1) begin
            probability = probs[i*16 +: 16] / 65535.0;

            $display(
                "Input[%0d] = %0d, Probability = %0.6f",
                i,
                $signed(logits[i*32 +: 32]),
                probability
            );

            probability_sum =
                probability_sum + probs[i*16 +: 16];
        end

        $display("-------------------------------------");
        $display("Sum of scaled probabilities = %0d",
                 probability_sum);
        $display("Waveform saved to softmax.vcd");
        $display("-------------------------------------");

        #20;
        $finish;
    end

endmodule
