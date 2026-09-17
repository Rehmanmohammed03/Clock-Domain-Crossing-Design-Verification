`timescale 1ns / 1ps

module pulse_sync (
    input  wire src_clk,
    input  wire src_rst_n,
    input  wire src_pulse,
    output wire src_busy,

    input  wire dst_clk,
    input  wire dst_rst_n,
    output wire dst_pulse
);

    // Toggle-based request/acknowledge handshake across clock domains.
    reg toggle_src;

    always @(posedge src_clk or negedge src_rst_n) begin
        if (!src_rst_n)
            toggle_src <= 1'b0;
        else if (src_pulse && !src_busy)
            toggle_src <= ~toggle_src;
    end

    // Synchronize the source toggle into the destination domain.
    wire toggle_dst_sync;

    sync_2ff #(
        .WIDTH       (1),
        .RESET_VALUE (0)
    ) u_sync_fwd (
        .clk      (dst_clk),
        .rst_n    (dst_rst_n),
        .async_in (toggle_src),
        .sync_out (toggle_dst_sync)
    );

    reg toggle_dst_sync_d;

    always @(posedge dst_clk or negedge dst_rst_n) begin
        if (!dst_rst_n)
            toggle_dst_sync_d <= 1'b0;
        else
            toggle_dst_sync_d <= toggle_dst_sync;
    end

    assign dst_pulse = toggle_dst_sync ^ toggle_dst_sync_d;

    // Echo the destination toggle back to the source domain.
    wire toggle_ack_src;

    sync_2ff #(
        .WIDTH       (1),
        .RESET_VALUE (0)
    ) u_sync_ret (
        .clk      (src_clk),
        .rst_n    (src_rst_n),
        .async_in (toggle_dst_sync),
        .sync_out (toggle_ack_src)
    );

    assign src_busy = (toggle_src != toggle_ack_src);

endmodule
