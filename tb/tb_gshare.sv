`timescale 1ns/1ps

module tb_gshare;

  reg         clk;
  reg         areset;

  reg         predict_valid;
  reg  [6:0]  predict_pc;
  wire        predict_taken;
  wire [6:0]  predict_history;

  reg         train_valid;
  reg         train_taken;
  reg         train_mispredicted;
  reg  [6:0]  train_history;
  reg  [6:0]  train_pc;

  top_module dut (
    .clk(clk),
    .areset(areset),

    .predict_valid(predict_valid),
    .predict_pc(predict_pc),
    .predict_taken(predict_taken),
    .predict_history(predict_history),

    .train_valid(train_valid),
    .train_taken(train_taken),
    .train_mispredicted(train_mispredicted),
    .train_history(train_history),
    .train_pc(train_pc)
  );

  // 10ns period
  initial clk = 1'b0;
  always #5 clk = ~clk;

  integer k;
  reg [6:0] pc;

  // Saved "history at prediction time"
  reg [6:0] hist_pred;
  reg [6:0] pred_idx;
  reg       exp_pred;
  reg       taken_pred;   // <-- capture the prediction bit that will be shifted in

  reg [6:0] train_idx;
  reg [1:0] before_ctr;
  reg [1:0] exp_ctr;

  reg       real_taken;
  reg       mispred;

  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, tb_gshare);

    // init
    predict_valid = 0;
    predict_pc    = 0;
    train_valid   = 0;
    train_pc      = 0;
    train_history = 0;
    train_taken   = 0;
    train_mispredicted = 0;

    // async reset pulse
    areset = 1'b1;
    #2;
    areset = 1'b0;

    repeat (3) @(posedge clk);

    // Sanity reset checks
    if (predict_history !== 7'b0) begin
      $display("[FAIL] GHR reset wrong: predict_history=%b", predict_history);
      $finish;
    end
    if (dut.pht[3] !== 2'b01) begin
      $display("[FAIL] PHT reset wrong: dut.pht[3]=%b (expected 01)", dut.pht[3]);
      $finish;
    end

    // -----------------------------
    // Directed: pc=3, train taken=1 (should increment counter)
    // -----------------------------
    pc = 7'd3;

    // PREDICT
    @(negedge clk);
    hist_pred     = predict_history;
    predict_pc    = pc;
    predict_valid = 1'b1;

    #1; // settle comb
    pred_idx  = (pc ^ hist_pred) & 7'h7F;
    exp_pred  = dut.pht[pred_idx][1];

    if (predict_taken !== exp_pred) begin
      $display("[FAIL] predict mismatch (directed) pc=%0d idx=%0d exp=%b got=%b ctr=%b hist=%b",
               pc, pred_idx, exp_pred, predict_taken, dut.pht[pred_idx], hist_pred);
      $finish;
    end

    taken_pred = exp_pred;  // capture the bit that will be shifted in

    @(posedge clk);         // DUT consumes predict_valid here

    @(negedge clk);
    predict_valid = 1'b0;

    #2;
    if (predict_history !== {hist_pred[5:0], taken_pred}) begin
      $display("[FAIL] GHR shift wrong after predict (directed): prev=%b taken_pred=%b now=%b",
               hist_pred, taken_pred, predict_history);
      $finish;
    end

    // TRAIN (use history-at-prediction-time)
    @(negedge clk);
    train_pc           = pc;
    train_history      = hist_pred;
    train_taken        = 1'b1;
    train_mispredicted = 1'b0;
    train_valid        = 1'b1;

    #1;
    train_idx  = (train_pc ^ train_history) & 7'h7F;
    before_ctr = dut.pht[train_idx];
    exp_ctr    = (before_ctr == 2'd3) ? 2'd3 : (before_ctr + 2'd1);

    @(posedge clk);

    @(negedge clk);
    train_valid = 1'b0;

    #2;
    if (dut.pht[train_idx] !== exp_ctr) begin
      $display("[FAIL] train update wrong (directed) idx=%0d before=%b exp=%b got=%b  pc=%0d hist=%b",
               train_idx, before_ctr, exp_ctr, dut.pht[train_idx], train_pc, train_history);
      $finish;
    end

    // -----------------------------
    // Random stress
    // -----------------------------
    for (k = 0; k < 500; k = k + 1) begin
      pc = $random;

      // PREDICT
      @(negedge clk);
      hist_pred     = predict_history;
      predict_pc    = pc;
      predict_valid = 1'b1;

      #1;
      pred_idx = (pc ^ hist_pred) & 7'h7F;
      exp_pred = dut.pht[pred_idx][1];

      if (predict_taken !== exp_pred) begin
        $display("[FAIL] predict mismatch (rand) pc=%0d idx=%0d exp=%b got=%b ctr=%b hist=%b",
                 pc, pred_idx, exp_pred, predict_taken, dut.pht[pred_idx], hist_pred);
        $finish;
      end

      taken_pred = exp_pred;   // <-- capture before posedge

      @(posedge clk);

      @(negedge clk);
      predict_valid = 1'b0;

      #2;
      if (predict_history !== {hist_pred[5:0], taken_pred}) begin
        $display("[FAIL] GHR shift wrong (rand): prev=%b taken_pred=%b now=%b",
                 hist_pred, taken_pred, predict_history);
        $finish;
      end

      // TRAIN
      real_taken = $random;
      mispred    = (real_taken != taken_pred) ? 1'b1 : ($random & 1'b1);

      @(negedge clk);
      train_pc           = pc;
      train_history      = hist_pred;
      train_taken        = real_taken;
      train_mispredicted = mispred;
      train_valid        = 1'b1;

      #1;
      train_idx  = (train_pc ^ train_history) & 7'h7F;
      before_ctr = dut.pht[train_idx];

      if (train_taken) exp_ctr = (before_ctr == 2'd3) ? 2'd3 : (before_ctr + 2'd1);
      else            exp_ctr = (before_ctr == 2'd0) ? 2'd0 : (before_ctr - 2'd1);

      @(posedge clk);

      @(negedge clk);
      train_valid = 1'b0;

      #2;
      if (dut.pht[train_idx] !== exp_ctr) begin
        $display("[FAIL] PHT update wrong (rand) idx=%0d before=%b taken=%b exp=%b got=%b",
                 train_idx, before_ctr, train_taken, exp_ctr, dut.pht[train_idx]);
        $finish;
      end

      if (train_mispredicted) begin
        if (predict_history !== {train_history[5:0], train_taken}) begin
          $display("[FAIL] rollback wrong (rand) exp=%b got=%b",
                   {train_history[5:0], train_taken}, predict_history);
          $finish;
        end
      end
    end

    $display("[PASS] TB checks passed.");
    $finish;
  end

endmodule