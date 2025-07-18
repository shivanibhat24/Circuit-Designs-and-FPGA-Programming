module ble_decoder_tb;

reg clk;
reg rst_n;
reg rf_data_in;
reg rf_data_valid;

wire [47:0] src_addr;
wire [47:0] dst_addr;
wire [7:0] packet_type;
wire [255:0] payload_data;
wire [7:0] payload_length;
wire packet_valid;
wire crc_error;
wire [7:0] debug_state;
wire [15:0] debug_rssi;

// Instantiate DUT
ble_decoder_top dut (
    .clk(clk),
    .rst_n(rst_n),
    .rf_data_in(rf_data_in),
    .rf_data_valid(rf_data_valid),
    .src_addr(src_addr),
    .dst_addr(dst_addr),
    .packet_type(packet_type),
    .payload_data(payload_data),
    .payload_length(payload_length),
    .packet_valid(packet_valid),
    .crc_error(crc_error),
    .debug_state(debug_state),
    .debug_rssi(debug_rssi)
);

// Clock generation
always #5 clk = ~clk;

// Test stimulus
initial begin
    // Initialize signals
    clk = 0;
    rst_n = 0;
    rf_data_in = 0;
    rf_data_valid = 0;
    
    // Reset
    #100 rst_n = 1;
    
    // Simulate BLE packet reception
    #200;
    rf_data_valid = 1;
    
    // Send preamble
    repeat (8) begin
        rf_data_in = 1;
        #10 rf_data_in = 0;
        #10;
    end
    
    // Send access address (0x8E89BED6)
    send_byte(8'h8E);
    send_byte(8'h89);
    send_byte(8'hBE);
    send_byte(8'hD6);
    
    // Send header
    send_byte(8'h42); // ADV_IND with 2-byte payload
    
    // Send address
    send_byte(8'h12);
    send_byte(8'h34);
    send_byte(8'h56);
    send_byte(8'h78);
    send_byte(8'h9A);
    send_byte(8'hBC);
    
    // Send payload
    send_byte(8'hDE);
    send_byte(8'hAD);
    
    // Send CRC
    send_byte(8'h00);
    send_byte(8'h00);
    send_byte(8'h00);
    
    rf_data_valid = 0;
    
    // Wait for processing
    #1000;
    
    // Check results
    if (packet_valid) begin
        $display("Packet decoded successfully!");
        $display("Source Address: %h", src_addr);
        $display("Packet Type: %h", packet_type);
        $display("Payload Length: %d", payload_length);
        $display("CRC Error: %b", crc_error);
    end else begin
        $display("Packet decode failed");
    end
    
    #1000 $finish;
end

// Task to send a byte
task send_byte;
    input [7:0] byte_data;
    integer i;
    begin
        for (i = 0; i < 8; i = i + 1) begin
            rf_data_in = byte_data[i];
            #20;
        end
    end
endtask

// Monitor
initial begin
    $monitor("Time: %t | State: %h | Valid: %b | Addr: %h | Type: %h", 
             $time, debug_state, packet_valid, src_addr, packet_type);
end

endmodule
