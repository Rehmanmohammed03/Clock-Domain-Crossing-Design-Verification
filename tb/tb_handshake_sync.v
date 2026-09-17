`timescale 1ns / 1ps
 
module tb_handshake_sync;
 
    // Test configuration.
    parameter NUM_TRANSFERS  = 30;
    parameter QUEUE_DEPTH    = 8;
    parameter GLOBAL_TIMEOUT = 200000; // ns

    reg global_rst_n;

    // Bounded pseudo-random delay helper.
    function integer rand_range;
        input integer max_val;
        integer r;
        begin
            r = $random % (max_val + 1);
            if (r < 0) r = -r;
            rand_range = r;
        end
    endfunction
 
    // Common reset for all DUT instances.
    initial begin
        global_rst_n = 1'b0;
        #83;
        global_rst_n = 1'b1;
    end
 
    // Simulation timeout guard.
    initial begin
        #GLOBAL_TIMEOUT;
        $display("[FAIL] TIMEOUT: simulation did not complete in time");
        $display("=====================================================");
        $display(" RESULT: FAIL (TIMEOUT)");
        $display("=====================================================");
        $finish;
    end
 
    // Instance 1: fast source, slow destination, 8-bit payload.
    localparam W1 = 8;
 
    reg              src_clk_1, dst_clk_1;
    reg              src_valid_1;
    reg  [W1-1:0]    src_data_1;
    wire             src_busy_1, src_ready_1;
    wire             dst_valid_1;
    wire [W1-1:0]    dst_data_1;
 
    initial src_clk_1 = 1'b0;
    always  #(4/2.0)  src_clk_1 = ~src_clk_1;
    initial dst_clk_1 = 1'b0;
    always  #(29/2.0) dst_clk_1 = ~dst_clk_1;
 
    handshake_sync #(.DATA_WIDTH(W1)) dut1 (
        .src_clk   (src_clk_1),
        .src_rst_n (global_rst_n),
        .src_valid (src_valid_1),
        .src_data  (src_data_1),
        .src_busy  (src_busy_1),
        .src_ready (src_ready_1),
        .dst_clk   (dst_clk_1),
        .dst_rst_n (global_rst_n),
        .dst_valid (dst_valid_1),
        .dst_data  (dst_data_1)
    );
 
    reg [W1-1:0] exp_q_1 [0:QUEUE_DEPTH-1];
    integer wr_ptr_1, rd_ptr_1;
    integer sent_1, received_1, error_1, check_1;
    reg done_1;
 
    // Scoreboard monitor for instance 1.
    always @(posedge dst_clk_1) begin
        if (global_rst_n && dst_valid_1) begin
            received_1 = received_1 + 1;
            if (rd_ptr_1 == wr_ptr_1) begin
                error_1 = error_1 + 1;
                $display("[FAIL][%0t] INST1: spurious dst_valid, scoreboard empty", $time);
            end else begin
                check_1 = check_1 + 1;
                if (dst_data_1 !== exp_q_1[rd_ptr_1 % QUEUE_DEPTH]) begin
                    error_1 = error_1 + 1;
                    $display("[FAIL][%0t] INST1: data mismatch. expected=%0h got=%0h",
                              $time, exp_q_1[rd_ptr_1 % QUEUE_DEPTH], dst_data_1);
                end
                rd_ptr_1 = rd_ptr_1 + 1;
            end
        end
    end
 
    // Driver for instance 1, including a protocol-violation check.
    integer i1;
    reg [W1-1:0] data_val_1, viol_val_1;
    initial begin
        src_valid_1 = 1'b0;
        src_data_1  = {W1{1'b0}};
        sent_1 = 0; received_1 = 0; error_1 = 0; check_1 = 0;
        wr_ptr_1 = 0; rd_ptr_1 = 0;
        done_1 = 1'b0;
 
        @(posedge global_rst_n);
        repeat (3) @(posedge src_clk_1);
 
        for (i1 = 0; i1 < NUM_TRANSFERS; i1 = i1 + 1) begin
            // Randomized idle gap; some sends are back-to-back.
            repeat (rand_range(4)) @(posedge src_clk_1);
 
            @(posedge src_clk_1);
            while (!src_ready_1) @(posedge src_clk_1);
 
            data_val_1 = $random;
            src_data_1  = data_val_1;
            src_valid_1 = 1'b1;
            exp_q_1[wr_ptr_1 % QUEUE_DEPTH] = data_val_1;
            wr_ptr_1 = wr_ptr_1 + 1;
            sent_1 = sent_1 + 1;
 
            @(posedge src_clk_1);
            src_valid_1 = 1'b0;
 
            // Inject a busy-while-valid violation and ensure it is ignored.
            if (i1 == NUM_TRANSFERS/2) begin
                if (src_busy_1 !== 1'b1) begin
                    error_1 = error_1 + 1;
                    $display("[FAIL][%0t] INST1: expected busy=1 immediately after send", $time);
                end else begin
                    check_1 = check_1 + 1;
                end
 
                viol_val_1 = $random;
                src_data_1  = viol_val_1;
                src_valid_1 = 1'b1; // Must be ignored while busy is asserted.
                @(posedge src_clk_1);
                src_valid_1 = 1'b0;
 
                check_1 = check_1 + 1;
                if (src_busy_1 !== 1'b1) begin
                    error_1 = error_1 + 1;
                    $display("[FAIL][%0t] INST1: busy deasserted early (violation not ignored)", $time);
                end
                // This value must never reach the destination queue.
            end
        end
 
        // Wait for the last transfer to finish.
        while (src_busy_1) @(posedge src_clk_1);
        repeat (10) @(posedge dst_clk_1);
        done_1 = 1'b1;
    end
 
    // Instance 2: slow source, fast destination, 16-bit payload.
    localparam W2 = 16;
 
    reg              src_clk_2, dst_clk_2;
    reg              src_valid_2;
    reg  [W2-1:0]    src_data_2;
    wire             src_busy_2, src_ready_2;
    wire             dst_valid_2;
    wire [W2-1:0]    dst_data_2;
 
    initial src_clk_2 = 1'b0;
    always  #(29/2.0) src_clk_2 = ~src_clk_2;
    initial dst_clk_2 = 1'b0;
    always  #(4/2.0)  dst_clk_2 = ~dst_clk_2;
 
    handshake_sync #(.DATA_WIDTH(W2)) dut2 (
        .src_clk   (src_clk_2),
        .src_rst_n (global_rst_n),
        .src_valid (src_valid_2),
        .src_data  (src_data_2),
        .src_busy  (src_busy_2),
        .src_ready (src_ready_2),
        .dst_clk   (dst_clk_2),
        .dst_rst_n (global_rst_n),
        .dst_valid (dst_valid_2),
        .dst_data  (dst_data_2)
    );
 
    reg [W2-1:0] exp_q_2 [0:QUEUE_DEPTH-1];
    integer wr_ptr_2, rd_ptr_2;
    integer sent_2, received_2, error_2, check_2;
    reg done_2;
 
    always @(posedge dst_clk_2) begin
        if (global_rst_n && dst_valid_2) begin
            received_2 = received_2 + 1;
            if (rd_ptr_2 == wr_ptr_2) begin
                error_2 = error_2 + 1;
                $display("[FAIL][%0t] INST2: spurious dst_valid, scoreboard empty", $time);
            end else begin
                check_2 = check_2 + 1;
                if (dst_data_2 !== exp_q_2[rd_ptr_2 % QUEUE_DEPTH]) begin
                    error_2 = error_2 + 1;
                    $display("[FAIL][%0t] INST2: data mismatch. expected=%0h got=%0h",
                              $time, exp_q_2[rd_ptr_2 % QUEUE_DEPTH], dst_data_2);
                end
                rd_ptr_2 = rd_ptr_2 + 1;
            end
        end
    end
 
    integer i2;
    reg [W2-1:0] data_val_2;
    initial begin
        src_valid_2 = 1'b0;
        src_data_2  = {W2{1'b0}};
        sent_2 = 0; received_2 = 0; error_2 = 0; check_2 = 0;
        wr_ptr_2 = 0; rd_ptr_2 = 0;
        done_2 = 1'b0;
 
        @(posedge global_rst_n);
        repeat (3) @(posedge src_clk_2);
 
        for (i2 = 0; i2 < NUM_TRANSFERS; i2 = i2 + 1) begin
            repeat (rand_range(3)) @(posedge src_clk_2);
 
            @(posedge src_clk_2);
            while (!src_ready_2) @(posedge src_clk_2);
 
            data_val_2 = $random;
            src_data_2  = data_val_2;
            src_valid_2 = 1'b1;
            exp_q_2[wr_ptr_2 % QUEUE_DEPTH] = data_val_2;
            wr_ptr_2 = wr_ptr_2 + 1;
            sent_2 = sent_2 + 1;
 
            @(posedge src_clk_2);
            src_valid_2 = 1'b0;
        end
 
        while (src_busy_2) @(posedge src_clk_2);
        repeat (10) @(posedge dst_clk_2);
        done_2 = 1'b1;
    end
 
    // Instance 3: near-equal-rate clocking, 4-bit payload.
    localparam W3 = 4;
 
    reg              src_clk_3, dst_clk_3;
    reg              src_valid_3;
    reg  [W3-1:0]    src_data_3;
    wire             src_busy_3, src_ready_3;
    wire             dst_valid_3;
    wire [W3-1:0]    dst_data_3;
 
    initial src_clk_3 = 1'b0;
    always  #(10/2.0)  src_clk_3 = ~src_clk_3;
    initial dst_clk_3 = 1'b0;
    always  #(9.7/2.0) dst_clk_3 = ~dst_clk_3;
 
    handshake_sync #(.DATA_WIDTH(W3)) dut3 (
        .src_clk   (src_clk_3),
        .src_rst_n (global_rst_n),
        .src_valid (src_valid_3),
        .src_data  (src_data_3),
        .src_busy  (src_busy_3),
        .src_ready (src_ready_3),
        .dst_clk   (dst_clk_3),
        .dst_rst_n (global_rst_n),
        .dst_valid (dst_valid_3),
        .dst_data  (dst_data_3)
    );
 
    reg [W3-1:0] exp_q_3 [0:QUEUE_DEPTH-1];
    integer wr_ptr_3, rd_ptr_3;
    integer sent_3, received_3, error_3, check_3;
    reg done_3;
 
    always @(posedge dst_clk_3) begin
        if (global_rst_n && dst_valid_3) begin
            received_3 = received_3 + 1;
            if (rd_ptr_3 == wr_ptr_3) begin
                error_3 = error_3 + 1;
                $display("[FAIL][%0t] INST3: spurious dst_valid, scoreboard empty", $time);
            end else begin
                check_3 = check_3 + 1;
                if (dst_data_3 !== exp_q_3[rd_ptr_3 % QUEUE_DEPTH]) begin
                    error_3 = error_3 + 1;
                    $display("[FAIL][%0t] INST3: data mismatch. expected=%0h got=%0h",
                              $time, exp_q_3[rd_ptr_3 % QUEUE_DEPTH], dst_data_3);
                end
                rd_ptr_3 = rd_ptr_3 + 1;
            end
        end
    end
 
    integer i3;
    reg [W3-1:0] data_val_3;
    initial begin
        src_valid_3 = 1'b0;
        src_data_3  = {W3{1'b0}};
        sent_3 = 0; received_3 = 0; error_3 = 0; check_3 = 0;
        wr_ptr_3 = 0; rd_ptr_3 = 0;
        done_3 = 1'b0;
 
        @(posedge global_rst_n);
        repeat (3) @(posedge src_clk_3);
 
        for (i3 = 0; i3 < NUM_TRANSFERS; i3 = i3 + 1) begin
            repeat (rand_range(5)) @(posedge src_clk_3);
 
            @(posedge src_clk_3);
            while (!src_ready_3) @(posedge src_clk_3);
 
            data_val_3 = $random;
            src_data_3  = data_val_3;
            src_valid_3 = 1'b1;
            exp_q_3[wr_ptr_3 % QUEUE_DEPTH] = data_val_3;
            wr_ptr_3 = wr_ptr_3 + 1;
            sent_3 = sent_3 + 1;
 
            @(posedge src_clk_3);
            src_valid_3 = 1'b0;
        end
 
        while (src_busy_3) @(posedge src_clk_3);
        repeat (10) @(posedge dst_clk_3);
        done_3 = 1'b1;
    end
 
    // Final aggregation and result summary.
    integer total_errors, total_checks, total_sent, total_received;
 
    initial begin
        $display("=====================================================");
        $display(" Handshake Synchronizer Testbench - Starting");
        $display("=====================================================");
 
        wait (done_1 && done_2 && done_3);
        #500; // margin for any trailing scoreboard activity
 
        total_errors   = error_1 + error_2 + error_3;
        total_checks   = check_1 + check_2 + check_3;
        total_sent     = sent_1 + sent_2 + sent_3;
        total_received = received_1 + received_2 + received_3;
 
        $display("-----------------------------------------------------");
        $display(" INST1 FAST_TO_SLOW (src=4ns,dst=29ns,W=8) : sent=%0d received=%0d checks=%0d errors=%0d",
                   sent_1, received_1, check_1, error_1);
        $display(" INST2 SLOW_TO_FAST (src=29ns,dst=4ns,W=16): sent=%0d received=%0d checks=%0d errors=%0d",
                   sent_2, received_2, check_2, error_2);
        $display(" INST3 NEAR_EQUAL   (src=10ns,dst=9.7ns,W=4): sent=%0d received=%0d checks=%0d errors=%0d",
                   sent_3, received_3, check_3, error_3);
        $display("-----------------------------------------------------");
        $display(" TOTAL sent=%0d received=%0d checks=%0d errors=%0d",
                   total_sent, total_received, total_checks, total_errors);
        $display("=====================================================");
 
        if ((total_errors == 0) && (total_sent == total_received) &&
            (rd_ptr_1 == wr_ptr_1) && (rd_ptr_2 == wr_ptr_2) && (rd_ptr_3 == wr_ptr_3)) begin
            $display(" RESULT: PASS");
        end else begin
            $display(" RESULT: FAIL");
        end
        $display("=====================================================");
        $finish;
    end
 
endmodule
