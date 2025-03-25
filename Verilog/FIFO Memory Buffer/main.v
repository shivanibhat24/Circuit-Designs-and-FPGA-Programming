module fifo_buffer #(
    parameter DATA_WIDTH = 8,            // Width of data
    parameter FIFO_DEPTH = 16,           // Depth of FIFO
    parameter ADDR_WIDTH = $clog2(FIFO_DEPTH) // Address width
)(
    input  wire                  clk,       // Clock signal
    input  wire                  rst_n,     // Active low reset
    input  wire                  wr_en,     // Write enable
    input  wire                  rd_en,     // Read enable
    input  wire [DATA_WIDTH-1:0] data_in,   // Data input
    output reg  [DATA_WIDTH-1:0] data_out,  // Data output
    output wire                  empty,     // FIFO empty flag
    output wire                  full       // FIFO full flag
);

    // Internal registers for FIFO storage
    reg [DATA_WIDTH-1:0] fifo_mem [0:FIFO_DEPTH-1];
    
    // Read and write pointers
    reg [ADDR_WIDTH:0] wr_ptr;
    reg [ADDR_WIDTH:0] rd_ptr;
    
    // FIFO count
    wire [ADDR_WIDTH:0] fifo_count = wr_ptr - rd_ptr;
    
    // Empty and full flags
    assign empty = (wr_ptr == rd_ptr);
    assign full = (fifo_count == FIFO_DEPTH);
    
    // Write operation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
        end else if (wr_en && !full) begin
            fifo_mem[wr_ptr[ADDR_WIDTH-1:0]] <= data_in;
            wr_ptr <= wr_ptr + 1;
        end
    end
    
    // Read operation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr <= 0;
            data_out <= 0;
        end else if (rd_en && !empty) begin
            data_out <= fifo_mem[rd_ptr[ADDR_WIDTH-1:0]];
            rd_ptr <= rd_ptr + 1;
        end
    end

endmodule
