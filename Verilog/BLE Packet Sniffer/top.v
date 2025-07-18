// Top-level module
module ble_decoder_top (
    input wire clk,              // System clock (100 MHz)
    input wire rst_n,            // Active low reset
    input wire rf_data_in,       // RF data input (1-bit after ADC)
    input wire rf_data_valid,    // RF data valid signal
    
    // Decoded packet outputs
    output wire [47:0] src_addr,
    output wire [47:0] dst_addr,
    output wire [7:0] packet_type,
    output wire [255:0] payload_data,
    output wire [7:0] payload_length,
    output wire packet_valid,
    output wire crc_error,
    
    // Debug outputs
    output wire [7:0] debug_state,
    output wire [15:0] debug_rssi
);

// Internal signals
wire clk_2M;                    // 2 MHz sampling clock for BLE
wire [7:0] demod_data;
wire demod_valid;
wire [7:0] sync_data;
wire sync_valid;
wire sync_found;
wire [7:0] decoded_byte;
wire decoded_valid;
wire [7:0] packet_state;

// Generate 2MHz clock from 100MHz system clock
clk_divider #(.DIVIDE_RATIO(50)) clk_div_2M (
    .clk_in(clk),
    .rst_n(rst_n),
    .clk_out(clk_2M)
);

// GFSK Demodulator
gfsk_demodulator demod (
    .clk(clk_2M),
    .rst_n(rst_n),
    .rf_data_in(rf_data_in),
    .rf_data_valid(rf_data_valid),
    .demod_data(demod_data),
    .demod_valid(demod_valid),
    .rssi(debug_rssi)
);

// Preamble and Access Address Detection
sync_detector sync_det (
    .clk(clk_2M),
    .rst_n(rst_n),
    .data_in(demod_data),
    .data_valid(demod_valid),
    .sync_data(sync_data),
    .sync_valid(sync_valid),
    .sync_found(sync_found)
);

// Packet Decoder
packet_decoder pkt_dec (
    .clk(clk_2M),
    .rst_n(rst_n),
    .data_in(sync_data),
    .data_valid(sync_valid),
    .sync_found(sync_found),
    .decoded_byte(decoded_byte),
    .decoded_valid(decoded_valid),
    .packet_state(packet_state)
);

// Protocol Handler
protocol_handler proto_handler (
    .clk(clk_2M),
    .rst_n(rst_n),
    .data_in(decoded_byte),
    .data_valid(decoded_valid),
    .packet_state(packet_state),
    .src_addr(src_addr),
    .dst_addr(dst_addr),
    .packet_type(packet_type),
    .payload_data(payload_data),
    .payload_length(payload_length),
    .packet_valid(packet_valid),
    .crc_error(crc_error)
);

assign debug_state = packet_state;

endmodule
