`timescale 1ns / 1ps

module reset_sync #(
    parameter SYNC_STAGES = 2
) (
    input  wire clk,
    input  wire async_rst_n,
    output wire sync_rst_n
);

    // Synchronize an asynchronous reset into the destination clock domain.
    reg [SYNC_STAGES-1:0] sync_ff;

    genvar stage_idx;
    generate
        for (stage_idx = 0; stage_idx < SYNC_STAGES; stage_idx = stage_idx + 1) begin : SYNC_CHAIN
            if (stage_idx == 0) begin : FIRST_STAGE
                always @(posedge clk or negedge async_rst_n) begin
                    if (!async_rst_n)
                        sync_ff[stage_idx] <= 1'b0;
                    else
                        sync_ff[stage_idx] <= 1'b1;
                end
            end else begin : NEXT_STAGE
                always @(posedge clk or negedge async_rst_n) begin
                    if (!async_rst_n)
                        sync_ff[stage_idx] <= 1'b0;
                    else
                        sync_ff[stage_idx] <= sync_ff[stage_idx-1];
                end
            end
        end
    endgenerate

    assign sync_rst_n = sync_ff[SYNC_STAGES-1];

endmodule
