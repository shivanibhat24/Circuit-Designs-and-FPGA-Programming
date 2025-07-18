module sync_detector (
    input wire clk,
    input wire rst_n,
    input wire [7:0] data_in,
    input wire data_valid,
    output reg [7:0] sync_data,
    output reg sync_valid,
    output reg sync_found
);

// BLE preamble and access address patterns
parameter PREAMBLE_AA = 8'b10101010;  // Preamble for advertising
parameter ACCESS_ADDR = 32'h8E89BED6; // Standard advertising access address

reg [31:0] shift_reg;
reg [2:0] state;
reg [7:0] byte_count;
reg preamble_found;

localparam IDLE = 3'b000;
localparam PREAMBLE_SEARCH = 3'b001;
localparam ACCESS_ADDR_SEARCH = 3'b010;
localparam PACKET_DATA = 3'b011;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        shift_reg <= 0;
        state <= IDLE;
        sync_data <= 0;
        sync_valid <= 0;
        sync_found <= 0;
        byte_count <= 0;
        preamble_found <= 0;
    end else if (data_valid) begin
        shift_reg <= {shift_reg[23:0], data_in};
        
        case (state)
            IDLE: begin
                if (data_in == PREAMBLE_AA) begin
                    state <= PREAMBLE_SEARCH;
                    preamble_found <= 1;
                end
            end
            
            PREAMBLE_SEARCH: begin
                if (preamble_found && shift_reg[31:0] == ACCESS_ADDR) begin
                    state <= PACKET_DATA;
                    sync_found <= 1;
                    byte_count <= 0;
                end else if (data_in != PREAMBLE_AA) begin
                    state <= IDLE;
                    preamble_found <= 0;
                end
            end
            
            PACKET_DATA: begin
                sync_data <= data_in;
                sync_valid <= 1;
                byte_count <= byte_count + 1;
                
                // Reset after maximum packet length
                if (byte_count >= 64) begin
                    state <= IDLE;
                    sync_found <= 0;
                    sync_valid <= 0;
                end
            end
            
            default: state <= IDLE;
        endcase
    end else begin
        sync_valid <= 0;
    end
end

endmodule
