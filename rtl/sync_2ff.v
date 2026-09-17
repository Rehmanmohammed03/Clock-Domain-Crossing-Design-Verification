`timescale 1ns / 1ps

module sync_2ff #(
    parameter WIDTH       = 1,
    parameter RESET_VALUE = 0
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire [WIDTH-1:0] async_in,
    output reg  [WIDTH-1:0] sync_out
);

    // Two-stage synchronizer for a CDC signal.
    reg [WIDTH-1:0] sync_ff1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync_ff1 <= {WIDTH{RESET_VALUE[0]}};
            sync_out <= {WIDTH{RESET_VALUE[0]}};
        end else begin
            sync_ff1 <= async_in;
            sync_out <= sync_ff1;
        end
    end

endmodule


