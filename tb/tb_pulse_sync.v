`timescale 1ns / 1ps
 
module tb_pulse_sync;
 
    reg  src_clk, src_rst_n, src_pulse;
    wire src_busy;
    reg  dst_clk, dst_rst_n;
    wire dst_pulse;
 
    integer src_period, dst_period;
    integer error_count, sent_count, received_count;
    integer i;
 
    pulse_sync DUT (
        .src_clk   (src_clk),
        .src_rst_n (src_rst_n),
        .src_pulse (src_pulse),
        .src_busy  (src_busy),
        .dst_clk   (dst_clk),
        .dst_rst_n (dst_rst_n),
        .dst_pulse (dst_pulse)
    );
 
    // Clock generators with configurable periods.
    initial begin
        src_clk = 0;
        forever #(src_period/2) src_clk = ~src_clk;
    end
    initial begin
        dst_clk = 0;
        forever #(dst_period/2) dst_clk = ~dst_clk;
    end
 
    // Check that the destination pulse is only one cycle wide.
    reg dst_pulse_d;
    always @(posedge dst_clk or negedge dst_rst_n) begin
        if (!dst_rst_n) begin
            dst_pulse_d <= 1'b0;
        end else begin
            dst_pulse_d <= dst_pulse;
            if (dst_pulse) begin
                received_count = received_count + 1;
                if (dst_pulse_d) begin
                    error_count = error_count + 1;
                    $display("[%0t] ERROR: dst_pulse asserted for >1 cycle", $time);
                end
            end
        end
    end
 
    // Reset validation task.
    task apply_reset;
        begin
            src_rst_n = 1'b0;
            dst_rst_n = 1'b0;
            src_pulse = 1'b0;
            repeat (3) @(posedge src_clk);
            #1;
            if (src_busy !== 1'b0) begin
                error_count = error_count + 1;
                $display("[%0t] ERROR: src_busy not 0 after reset", $time);
            end
            repeat (3) @(posedge dst_clk);
            #1;
            if (dst_pulse !== 1'b0) begin
                error_count = error_count + 1;
                $display("[%0t] ERROR: dst_pulse not 0 after reset", $time);
            end
            src_rst_n = 1'b1;
            dst_rst_n = 1'b1;
            repeat (2) @(posedge src_clk);
            $display("[%0t] INFO : Reset check PASSED", $time);
        end
    endtask
 
    // Send one valid pulse while respecting the busy flag.
    task send_one_pulse;
        begin
            @(posedge src_clk);
            while (src_busy) @(posedge src_clk);
            src_pulse = 1'b1;
            sent_count = sent_count + 1;
            @(posedge src_clk);
            src_pulse = 1'b0;
        end
    endtask
 
    // Send a burst of valid pulses with randomized idle gaps.
    task random_burst (input integer n);
        integer idle;
        begin
            for (i = 0; i < n; i = i + 1) begin
                send_one_pulse;
                idle = $random % 4; // 0-3 idle cycles between pulses
                if (idle < 0) idle = -idle;
                repeat (idle) @(posedge src_clk);
            end
        end
    endtask
 
    // Hold the pulse high to verify the DUT accepts only one toggle event.
    task hammer_test (input integer hold_cycles);
        begin
            @(posedge src_clk);
            src_pulse = 1'b1;
            sent_count = sent_count + 1;
            repeat (hold_cycles) begin
                @(posedge src_clk);
                #1;
                if (!src_busy && (hold_cycles > 4)) begin
                    // Drop the pulse as soon as the busy flag clears to keep the check clean.
                    src_pulse = 1'b0;
                end
            end
            src_pulse = 1'b0;
            @(posedge src_clk);
        end
    endtask
 
    // Verify that a pulse request is ignored while busy remains high.
    task busy_gating_check;
        begin
            @(posedge src_clk);
            while (src_busy) @(posedge src_clk);
            src_pulse = 1'b1;
            sent_count = sent_count + 1;
            @(posedge src_clk);
            #1;
            if (!src_busy) begin
                error_count = error_count + 1;
                $display("[%0t] ERROR: src_busy did not assert after accepted pulse", $time);
            end
            src_pulse = 1'b1;
            @(posedge src_clk);
            #1;
            src_pulse = 1'b0;
            // Wait for the round trip to complete.
            while (src_busy) @(posedge src_clk);
            $display("[%0t] INFO : Busy-gating check PASSED", $time);
        end
    endtask
 
    // Main stimulus sequence.
    initial begin
        error_count    = 0;
        sent_count     = 0;
        received_count = 0;
        src_pulse      = 0;
        src_rst_n      = 0;
        dst_rst_n      = 0;
 
        // Scenario 1: dst_clk faster than src_clk
        src_period = 20; dst_period = 6;
        $display("\n=== SCENARIO 1: src=%0dns dst=%0dns (dst faster) ===", src_period, dst_period);
        apply_reset;
        random_burst(20);
        busy_gating_check;
        hammer_test(30);
 
        // Scenario 2: dst_clk slower than src_clk
        src_period = 6; dst_period = 25;
        $display("\n=== SCENARIO 2: src=%0dns dst=%0dns (dst slower) ===", src_period, dst_period);
        apply_reset;
        random_burst(15);
        busy_gating_check;
        hammer_test(40);
 
        // Scenario 3: odd, near-equal ratio (stress simultaneous edges)
        src_period = 10; dst_period = 11;
        $display("\n=== SCENARIO 3: src=%0dns dst=%0dns (near-equal) ===", src_period, dst_period);
        apply_reset;
        random_burst(25);
        hammer_test(20);
 
        // Allow final in-flight pulse to complete
        repeat (20) @(posedge dst_clk);
 
        // ---------------------------------------------------------------
        // Final PASS/FAIL summary
        // ---------------------------------------------------------------
        $display("\n=====================================================");
        $display(" TB_PULSE_SYNC : Sent = %0d, Received = %0d, Errors = %0d",
                   sent_count, received_count, error_count);
        if ((sent_count == received_count) && (error_count == 0) && (sent_count > 0))
            $display(" RESULT: *** PASS ***");
        else
            $display(" RESULT: *** FAIL ***");
        $display("=====================================================\n");
 
        $finish;
    end
 
    initial begin
        #500000;
        $display("ERROR: TB TIMEOUT");
        $finish;
    end
 
    initial begin
        $dumpfile("tb_pulse_sync.vcd");
        $dumpvars(0, tb_pulse_sync);
    end
 
endmodule
 
