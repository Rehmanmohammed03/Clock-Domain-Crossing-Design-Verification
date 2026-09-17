`timescale 1ns / 1ps

module handshake_sync #(
    parameter DATA_WIDTH = 8
) (
    input  wire                  src_clk,
    input  wire                  src_rst_n,
    input  wire                  src_valid,
    input  wire [DATA_WIDTH-1:0] src_data,
    output wire                  src_busy,
    output wire                  src_ready,

    input  wire                  dst_clk,
    input  wire                  dst_rst_n,
    output reg                   dst_valid,
    output reg  [DATA_WIDTH-1:0] dst_data
);

    // Request/acknowledge handshake with a data-hold register.
    reg                  req_toggle;
    reg [DATA_WIDTH-1:0] data_hold;
    reg                  busy;

    // Synchronize destination ACK back into the source domain.
    reg ack_sync_meta, ack_sync;
    always @(posedge src_clk or negedge src_rst_n) begin
        if (!src_rst_n) begin
            ack_sync_meta <= 1'b0;
            ack_sync      <= 1'b0;
        end else begin
            ack_sync_meta <= ack_toggle;
            ack_sync      <= ack_sync_meta;
        end
    end

    // Source-domain request and busy tracking.
    always @(posedge src_clk or negedge src_rst_n) begin
        if (!src_rst_n) begin
            req_toggle <= 1'b0;
            data_hold  <= {DATA_WIDTH{1'b0}};
            busy       <= 1'b0;
        end else if (src_valid && !busy) begin
            data_hold  <= src_data;
            req_toggle <= ~req_toggle;
            busy       <= 1'b1;
        end else if (busy && (ack_sync == req_toggle)) begin
            busy <= 1'b0;
        end
    end

    assign src_busy  = busy;
    assign src_ready = ~busy;

    // Destination-domain request capture and acknowledge generation.
    reg req_sync_meta, req_sync, req_sync_prev;
    reg ack_toggle;

    always @(posedge dst_clk or negedge dst_rst_n) begin
        if (!dst_rst_n) begin
            req_sync_meta <= 1'b0;
            req_sync      <= 1'b0;
        end else begin
            req_sync_meta <= req_toggle;
            req_sync      <= req_sync_meta;
        end
    end

    always @(posedge dst_clk or negedge dst_rst_n) begin
        if (!dst_rst_n)
            req_sync_prev <= 1'b0;
        else
            req_sync_prev <= req_sync;
    end

    wire req_edge = (req_sync != req_sync_prev);

    always @(posedge dst_clk or negedge dst_rst_n) begin
        if (!dst_rst_n) begin
            dst_valid  <= 1'b0;
            dst_data   <= {DATA_WIDTH{1'b0}};
            ack_toggle <= 1'b0;
        end else if (req_edge) begin
            dst_data   <= data_hold;
            dst_valid  <= 1'b1;
            ack_toggle <= ~ack_toggle;
        end else begin
            dst_valid  <= 1'b0;
        end
    end

endmodule