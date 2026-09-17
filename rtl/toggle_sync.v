`timescale 1ns / 1ps

module toggle_sync (
    input  wire dst_clk,
    input  wire dst_rst_n,
    input  wire src_toggle,
    output wire dst_toggle_sync,
    output wire dst_pulse
);

    // Synchronize an asynchronous toggle into the destination clock domain.
    sync_2ff #(
        .WIDTH       (1),
        .RESET_VALUE (0)
    ) u_sync (
        .clk      (dst_clk),
        .rst_n    (dst_rst_n),
        .async_in (src_toggle),
        .sync_out (dst_toggle_sync)
    );

    // One-cycle pulse on each detected transition in the synchronized toggle.
    reg dst_toggle_sync_d;

    always @(posedge dst_clk or negedge dst_rst_n) begin
        if (!dst_rst_n)
            dst_toggle_sync_d <= 1'b0;
        else
            dst_toggle_sync_d <= dst_toggle_sync;
    end

    assign dst_pulse = dst_toggle_sync ^ dst_toggle_sync_d;

endmodule
