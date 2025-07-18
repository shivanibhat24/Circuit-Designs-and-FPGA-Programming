module protocol_handler (
    input wire clk,
    input wire rst_n,
    input wire [7:0] data_in,
    input wire data_valid,
    input wire [7:0] packet_state,
    output reg [47:0] src_addr,
    output reg [47:0] dst_addr,
    output reg [7:0] packet_type,
    output reg [255:0] payload_data,
    output reg [7:0] payload_length,
    output reg packet_valid,
    output reg crc_error
);

// Internal registers
reg [7:0] header;
reg [7:0] addr_bytes [0:5];
reg [7:0] payload_bytes [0:31];
reg [7:0] crc_bytes [0:2];
reg [7:0] byte_index;
reg [2:0] addr_index;
reg [7:0] payload_index;
reg [2:0] crc_index;
reg [2:0] decode_state;

// Protocol decode states
localparam DECODE_IDLE = 3'b000;
localparam DECODE_HEADER = 3'b001;
localparam DECODE_ADDR = 3'b010;
localparam DECODE_PAYLOAD = 3'b011;
localparam DECODE_CRC = 3'b100;
localparam DECODE_COMPLETE = 3'b101;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        src_addr <= 0;
        dst_addr <= 0;
        packet_type <= 0;
        payload_data <= 0;
        payload_length <= 0;
        packet_valid <= 0;
        crc_error <= 0;
        decode_state <= DECODE_IDLE;
        byte_index <= 0;
        addr_index <= 0;
        payload_index <= 0;
        crc_index <= 0;
    end else if (data_valid) begin
        case (decode_state)
            DECODE_IDLE: begin
                if (packet_state == 8'h01) begin // PKT_HEADER
                    decode_state <= DECODE_HEADER;
                end
            end
            
            DECODE_HEADER: begin
                header <= data_in;
                packet_type <= data_in[3:0];
                payload_length <= data_in[5:0];
                decode_state <= DECODE_ADDR;
                addr_index <= 0;
            end
            
            DECODE_ADDR: begin
                addr_bytes[addr_index] <= data_in;
                addr_index <= addr_index + 1;
                
                if (addr_index == 5) begin
                    // Construct source address
                    src_addr <= {addr_bytes[5], addr_bytes[4], addr_bytes[3], 
                                addr_bytes[2], addr_bytes[1], addr_bytes[0]};
                    decode_state <= DECODE_PAYLOAD;
                    payload_index <= 0;
                end
            end
            
            DECODE_PAYLOAD: begin
                if (payload_index < payload_length) begin
                    payload_bytes[payload_index] <= data_in;
                    payload_index <= payload_index + 1;
                    
                    // Pack payload data
                    payload_data <= {payload_data[247:0], data_in};
                end
                
                if (payload_index >= payload_length - 1) begin
                    decode_state <= DECODE_CRC;
                    crc_index <= 0;
                end
            end
            
            DECODE_CRC: begin
                crc_bytes[crc_index] <= data_in;
                crc_index <= crc_index + 1;
                
                if (crc_index == 2) begin
                    decode_state <= DECODE_COMPLETE;
                    // Simple CRC check (normally would use CRC-24)
                    crc_error <= (crc_bytes[0] == 8'h00) ? 0 : 1;
                end
            end
            
            DECODE_COMPLETE: begin
                packet_valid <= 1;
                decode_state <= DECODE_IDLE;
            end
            
            default: decode_state <= DECODE_IDLE;
        endcase
    end else begin
        packet_valid <= 0;
    end
end

endmodule
