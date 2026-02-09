module pht_mem (
    input  clk,
    input  areset,

    // Read port (for prediction)
    input  [6:0] raddr,
    output [1:0] rdata,

    // Train port (for update)
    input        train_valid,
    input        train_taken,
    input  [6:0] train_index
);
    // 128-entry Pattern History Table of 2-bit counters
    reg [1:0] pht [127:0];
    integer i;

    // Combinational read (matches your original: pht[predict_index])
    assign rdata = pht[raddr];

    always @(posedge clk, posedge areset) begin
        if (areset) begin
            // Initialize all counters to weakly-not-taken (01)
            for (i = 0; i < 128; i = i + 1)
                pht[i] <= 2'b01;
        end else if (train_valid) begin
            // Saturating update
            if (train_taken) begin
                if (pht[train_index] != 2'd3)
                    pht[train_index] <= pht[train_index] + 2'd1;
            end else begin
                if (pht[train_index] != 2'd0)
                    pht[train_index] <= pht[train_index] - 2'd1;
            end
        end
    end
endmodule


module top_module(
    input clk,
    input areset,

    input  predict_valid,
    input  [6:0] predict_pc,
    output predict_taken,
    output reg [6:0] predict_history,

    input train_valid,
    input train_taken,
    input train_mispredicted,
    input [6:0] train_history,
    input [6:0] train_pc
);

    // Indices for gshare: PC XOR history
    wire [6:0] predict_index = predict_pc ^ predict_history;
    wire [6:0] train_index   = train_pc  ^ train_history;

    // Counter read from PHT
    wire [1:0] predict_counter;

    // PHT as a separate module (so we can blackbox it in Yosys)
    pht_mem pht0 (
        .clk(clk),
        .areset(areset),
        .raddr(predict_index),
        .rdata(predict_counter),
        .train_valid(train_valid),
        .train_taken(train_taken),
        .train_index(train_index)
    );

    // Prediction is MSB of the 2-bit counter
    assign predict_taken = predict_counter[1];

    always @(posedge clk, posedge areset) begin
        if (areset) begin
            // Reset GHR to 0
            predict_history <= 7'b0;
        end else begin
            // Update GHR (training rollback takes precedence)
            if (train_valid && train_mispredicted)
                predict_history <= {train_history[5:0], train_taken};
            else if (predict_valid)
                predict_history <= {predict_history[5:0], predict_taken};
        end
    end

endmodule