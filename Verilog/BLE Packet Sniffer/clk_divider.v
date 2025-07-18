module clk_divider #(
    parameter DIVIDE_RATIO = 50
) (
    input wire clk_in,
    input wire rst_n,
    output reg clk_out
);

reg [$clog2(DIVIDE_RATIO)-1:0] counter;

always @(posedge clk_in or negedge rst_n) begin
    if (!rst_n) begin
        counter <= 0;
        clk_out <= 0;
    end else begin
        if (counter == DIVIDE_RATIO-1) begin
            counter <= 0;
            clk_out <= ~clk_out;
        end else begin
            counter <= counter + 1;
        end
    end
end

endmodule
