module switch_debouncer #(
    parameter DEBOUNCE_COUNT = 1000000,  // Default for ~20ms at 50MHz
    parameter COUNT_WIDTH = $clog2(DEBOUNCE_COUNT)
)(
    input  wire clk,           // System clock
    input  wire rst_n,         // Active low reset
    input  wire switch_in,     // Raw input from switch
    output reg  switch_out,    // Debounced switch output
    output reg  switch_edge,   // Pulses for one clock when switch changes
    output reg  switch_pressed // High when switch is pressed (edge detection)
);

    // Define states
    localparam IDLE = 2'b00;
    localparam CHECK_NOISE = 2'b01;
    localparam WAIT_STABLE = 2'b10;
    
    // State registers
    reg [1:0] state, next_state;
    
    // Counter for timing
    reg [COUNT_WIDTH-1:0] counter;
    
    // Registered input to detect edges
    reg switch_in_reg;
    
    // State machine for debouncing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 0;
            switch_out <= 0;
            switch_edge <= 0;
            switch_pressed <= 0;
            switch_in_reg <= 0;
        end else begin
            // Default assignment
            switch_edge <= 0;
            
            // Register the input for edge detection
            switch_in_reg <= switch_in;
            
            case (state)
                IDLE: begin
                    if (switch_in != switch_out) begin
                        state <= CHECK_NOISE;
                        counter <= 0;
                    end
                end
                
                CHECK_NOISE: begin
                    if (switch_in != switch_out) begin
                        counter <= counter + 1;
                        if (counter >= DEBOUNCE_COUNT - 1) begin
                            switch_out <= switch_in;
                            switch_edge <= 1;
                            // Update pressed status on positive edge only
                            if (switch_in && !switch_out)
                                switch_pressed <= 1;
                            else if (!switch_in && switch_out)
                                switch_pressed <= 0;
                            state <= IDLE;
                        end
                    end else begin
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
