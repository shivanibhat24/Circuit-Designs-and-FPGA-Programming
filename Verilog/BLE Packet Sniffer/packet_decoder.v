module packet_decoder (
    input wire clk,
    input wire rst_n,
    input wire [7:0] data_in,
    input wire data_valid,
    input wire sync_found,
    output reg [7:0] decoded_byte,
    output reg decoded_valid,
    output reg [7:0] packet_state
);

// Packet states
localparam PKT_IDLE = 8'h00;
localparam PKT_HEADER = 8'h01;
localparam PKT_PAYLOAD = 8'h02;
localparam PKT_CRC = 8'h03;
localparam PKT_DONE = 8'h04;

reg [7:0] header_byte;
reg [5:0] payload_length;
reg [7:0] byte_counter;
reg [23:0] crc_reg;

// Data whitening LFSR
reg [6:0] whitening_lfsr;
wire whitening_bit = whitening_lfsr[6] ^ whitening_lfsr[3];
wire [7:0] dewhitened_data = data_in ^ {8{whitening_bit}};

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        packet_state <= PKT_IDLE;
        decoded_byte <= 0;
        decoded_valid <= 0;
        header_byte <= 0;
        payload_length <= 0;
        byte_counter <= 0;
        crc_reg <= 0;
        whitening_lfsr <= 7'h40; // Initialize whitening
    end else if (sync_found && data_valid) begin
        case (packet_state)
            PKT_IDLE: begin
                packet_state <= PKT_HEADER;
                byte_counter <= 0;
                whitening_lfsr <= 7'h40;
            end
            
            PKT_HEADER: begin
                header_byte <= dewhitened_data;
                payload_length <= dewhitened_data[5:0]; // Extract length
                decoded_byte <= dewhitened_data;
                decoded_valid <= 1;
                packet_state <= PKT_PAYLOAD;
                byte_counter <= 0;
                
                // Update CRC
                crc_reg <= crc_reg ^ {16'h0000, dewhitened_data};
            end
            
            PKT_PAYLOAD: begin
                decoded_byte <= dewhitened_data;
                decoded_valid <= 1;
                byte_counter <= byte_counter + 1;
                
                // Update CRC
                crc_reg <= crc_reg ^ {16'h0000, dewhitened_data};
                
                if (byte_counter >= payload_length - 1) begin
                    packet_state <= PKT_CRC;
                    byte_counter <= 0;
                end
            end
            
            PKT_CRC: begin
                decoded_byte <= dewhitened_data;
                decoded_valid <= 1;
                byte_counter <= byte_counter + 1;
                
                if (byte_counter >= 2) begin // 3 CRC bytes
                    packet_state <= PKT_DONE;
                end
            end
            
            PKT_DONE: begin
                packet_state <= PKT_IDLE;
                decoded_valid <= 0;
            end
            
            default: packet_state <= PKT_IDLE;
        endcase
        
        // Update whitening LFSR
        whitening_lfsr <= {whitening_lfsr[5:0], whitening_bit};
    end else begin
        decoded_valid <= 0;
        if (!sync_found) begin
            packet_state <= PKT_IDLE;
        end
    end
end

endmodule
