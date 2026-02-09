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
    
    // 128 entry Pattern History Table of 2 bit counters
    reg [1:0] pht [127:0];
    
    integer i;
    
    wire [6:0] predict_index = predict_pc ^ predict_history;
    wire [1:0] predict_counter = pht[predict_index];
    
    assign predict_taken = predict_counter[1];
    
    wire [6:0] train_index = train_pc ^ train_history;
    
    always @(posedge clk, posedge areset) begin
        // Reset GHR and PHT Counters
        if (areset) begin
            predict_history <= 7'b0;
            for (i = 0; i < 128; i = i + 1)
                pht[i] <= 2'b01;
        end else begin
            // Train PHT
            if (train_valid) begin
                if (train_taken) begin
                    if (pht[train_index] != 2'd3)
                        pht[train_index] <= pht[train_index] + 2'd1;
                end else begin
                    if (pht[train_index] != 2'd0)
                        pht[train_index] <= pht[train_index] - 2'd1;
                end
            end
            
            // Update GHR
            if (train_valid && train_mispredicted)
                predict_history <= {train_history[5:0], train_taken};
            else if (predict_valid)
                predict_history <= {predict_history[5:0], predict_taken};
            
        end
    end

endmodule
