module d_flip_flop (
    input wire clk,           // Clock input
    input wire d,             // Data input
    input wire enable,        // Enable signal
    input wire sync_reset,    // Synchronous reset (active high)
    input wire async_reset_n, // Asynchronous reset (active low)
    output reg q,             // Output
    output wire q_bar         // Complementary output
);

    // Complementary output
    assign q_bar = ~q;
    
    // D flip-flop behavior with asynchronous reset and synchronous reset
    always @(posedge clk or negedge async_reset_n) begin
        if (!async_reset_n) begin
            // Asynchronous reset (active low)
            q <= 1'b0;
        end else if (sync_reset) begin
            // Synchronous reset (active high)
            q <= 1'b0;
        end else if (enable) begin
            // Normal operation when enabled
            q <= d;
        end
        // Hold value when enable is low
    end

endmodule
