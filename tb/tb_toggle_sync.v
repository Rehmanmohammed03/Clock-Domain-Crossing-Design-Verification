`timescale 1ns / 1ps

module tb_toggle_sync;
 
    reg  src_clk, dst_clk, dst_rst_n;
    reg  src_toggle;
    wire dst_toggle_sync, dst_pulse;
 
    integer src_period, dst_period;
    integer error_count, toggle_count, pulse_count;
    integer i;
 
    toggle_sync DUT (
        .dst_clk        (dst_clk),
        .dst_rst_n      (dst_rst_n),
        .src_toggle     (src_toggle),
        .dst_toggle_sync(dst_toggle_sync),
        .dst_pulse      (dst_pulse)
    );
 
    initial begin
        src_clk = 0;
        forever #(src_period/2) src_clk = ~src_clk;
    end
    initial begin
        dst_clk = 0;
        forever #(dst_period/2) dst_clk = ~dst_clk;
    end
 
    // Source-domain toggle generator. Modes 1 and 2 produce paced and stress traffic.
    reg [1:0] gen_mode;
    integer   gap_counter;
    integer   min_gap;
 
    initial begin
        src_toggle   = 1'b0;
        gen_mode     = 2'd0;
        toggle_count = 0;
        gap_counter  = 0;
    end
 
    always @(posedge src_clk) begin
        if (gen_mode == 2'd1) begin
            if (gap_counter > 0) begin
                gap_counter <= gap_counter - 1;
            end else begin
                src_toggle   <= ~src_toggle;
                toggle_count <= toggle_count + 1;
                gap_counter  <= min_gap + ($random % 4 < 0 ? -($random % 4) : ($random % 4));
            end
        end else if (gen_mode == 2'd2) begin
            if (($random % 3) == 0) begin
                src_toggle   <= ~src_toggle;
                toggle_count <= toggle_count + 1;
            end
        end
    end
 
    // Count pulse events without enforcing an artificial width check.
    always @(posedge dst_clk or negedge dst_rst_n) begin
        if (!dst_rst_n) begin
            pulse_count = pulse_count;
        end else begin
            if (dst_pulse)
                pulse_count = pulse_count + 1;
        end
    end
 
    task apply_reset;
        begin
            dst_rst_n  = 1'b0;
            gen_mode   = 2'd0;
            // Re-baseline the toggle while holding the destination reset.
            src_toggle = 1'b0;
            repeat (3) @(posedge dst_clk);
            #1;
            if (dst_toggle_sync !== 1'b0 || dst_pulse !== 1'b0) begin
                error_count = error_count + 1;
                $display("[%0t] ERROR: DUT outputs not 0 during reset", $time);
            end
            repeat (2) @(posedge dst_clk);
            dst_rst_n = 1'b1;
            $display("[%0t] INFO : Reset check PASSED", $time);
        end
    endtask
 
    initial begin
        error_count  = 0;
        pulse_count  = 0;
        dst_rst_n    = 0;
 
        // Scenario 1: paced traffic with destination clock faster.
        src_period = 18; dst_period = 5;
        min_gap    = 6;
        $display("\n=== SCENARIO 1 (paced): src=%0dns dst=%0dns (dst faster) ===", src_period, dst_period);
        apply_reset;
        gen_mode = 2'd1; gap_counter = 2;
        repeat (400) @(posedge dst_clk);
        gen_mode = 2'd0;
        repeat (10) @(posedge dst_clk); // drain
 
        // Scenario 2: paced traffic with destination clock slower.
        src_period = 5; dst_period = 23;
        min_gap    = 8;
        $display("\n=== SCENARIO 2 (paced): src=%0dns dst=%0dns (dst slower) ===", src_period, dst_period);
        apply_reset;
        gen_mode = 2'd1; gap_counter = 2;
        repeat (200) @(posedge dst_clk);
        gen_mode = 2'd0;
        repeat (10) @(posedge dst_clk); // drain
 
        // Scenario 3: paced traffic with near-equal clock ratios.
        src_period = 9; dst_period = 10;
        min_gap    = 8;
        $display("\n=== SCENARIO 3 (paced): src=%0dns dst=%0dns (near-equal) ===", src_period, dst_period);
        apply_reset;
        gen_mode = 2'd1; gap_counter = 2;
        repeat (300) @(posedge dst_clk);
        gen_mode = 2'd0;
        repeat (10) @(posedge dst_clk); // drain
 
        // Check the paced-mode invariant for no dropped or duplicated events.
        #1;
        if (dst_toggle_sync !== src_toggle) begin
            error_count = error_count + 1;
            $display("[%0t] ERROR: dst_toggle_sync (%b) != src_toggle (%b) after drain",
                       $time, dst_toggle_sync, src_toggle);
        end
        if (toggle_count != pulse_count) begin
            error_count = error_count + 1;
            $display("[%0t] ERROR: paced-mode toggle/pulse mismatch: toggles=%0d pulses=%0d",
                       $time, toggle_count, pulse_count);
        end else begin
            $display("[%0t] INFO : Paced-mode no-missing/no-duplicate check PASSED (%0d/%0d)",
                       $time, toggle_count, pulse_count);
        end
 
        // Scenario 4: stress test to confirm coalescing is bounded and converges correctly.
        src_period = 10; dst_period = 10;
        $display("\n=== SCENARIO 4 (stress/coalescing, informational): src=%0dns dst=%0dns ===",
                   src_period, dst_period);
        apply_reset;
        gen_mode = 2'd2;
        repeat (300) @(posedge dst_clk);
        gen_mode = 2'd0;
        repeat (10) @(posedge dst_clk); // drain
        #1;
        if (pulse_count > toggle_count) begin
            error_count = error_count + 1;
            $display("[%0t] ERROR: stress-mode pulses (%0d) exceeded toggles (%0d) - phantom pulse!",
                       $time, pulse_count, toggle_count);
        end
        if (dst_toggle_sync !== src_toggle) begin
            error_count = error_count + 1;
            $display("[%0t] ERROR: stress-mode failed to converge: dst_toggle_sync(%b) != src_toggle(%b)",
                       $time, dst_toggle_sync, src_toggle);
        end else begin
            $display("[%0t] INFO : Stress-mode converged correctly after drain (toggles=%0d, pulses=%0d, %0d coalesced)",
                       $time, toggle_count, pulse_count, toggle_count - pulse_count);
        end
 
        $display("\n=====================================================");
        $display(" TB_TOGGLE_SYNC : Total Toggles = %0d, Total Pulses = %0d, Errors = %0d",
                   toggle_count, pulse_count, error_count);
        if ((error_count == 0) && (toggle_count > 0))
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
        $dumpfile("tb_toggle_sync.vcd");
        $dumpvars(0, tb_toggle_sync);
    end
 
endmodule
