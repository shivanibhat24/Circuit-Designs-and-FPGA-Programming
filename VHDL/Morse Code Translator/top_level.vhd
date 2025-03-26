-- top_level.vhd
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity morse_translator_top is
    Port ( 
        clk         : in STD_LOGIC;
        reset       : in STD_LOGIC;
        uart_rx     : in STD_LOGIC;
        uart_tx     : out STD_LOGIC;
        led_output  : out STD_LOGIC;
        buzzer      : out STD_LOGIC;
        keypad_in   : in STD_LOGIC_VECTOR(3 downto 0)
    );
end morse_translator_top;

architecture Behavioral of morse_translator_top is
    -- Internal signals
    signal uart_data_out    : STD_LOGIC_VECTOR(7 downto 0);
    signal uart_data_valid  : STD_LOGIC;
    signal morse_encoded    : STD_LOGIC;
    signal morse_decoded    : STD_LOGIC_VECTOR(7 downto 0);
    signal clk_divided      : STD_LOGIC;

    -- Component Declarations
    component clock_divider
        Port ( 
            clk_in  : in STD_LOGIC;
            clk_out : out STD_LOGIC
        );
    end component;

    component uart_rx
        Port ( 
            clk     : in STD_LOGIC;
            rx      : in STD_LOGIC;
            data    : out STD_LOGIC_VECTOR(7 downto 0);
            valid   : out STD_LOGIC
        );
    end component;

    component morse_encoder
        Port ( 
            clk         : in STD_LOGIC;
            reset       : in STD_LOGIC;
            char_in     : in STD_LOGIC_VECTOR(7 downto 0);
            morse_out   : out STD_LOGIC;
            encoding_done : out STD_LOGIC
        );
    end component;

    component morse_decoder
        Port ( 
            clk         : in STD_LOGIC;
            reset       : in STD_LOGIC;
            morse_in    : in STD_LOGIC;
            char_out    : out STD_LOGIC_VECTOR(7 downto 0);
            valid       : out STD_LOGIC
        );
    end component;

    component fsm_controller
        Port ( 
            clk             : in STD_LOGIC;
            reset           : in STD_LOGIC;
            uart_data       : in STD_LOGIC_VECTOR(7 downto 0);
            uart_valid      : in STD_LOGIC;
            morse_encoded   : in STD_LOGIC;
            morse_decoded   : in STD_LOGIC_VECTOR(7 downto 0);
            led_control     : out STD_LOGIC;
            buzzer_control  : out STD_LOGIC
        );
    end component;

begin
    -- Clock Divider Instance
    clk_div_inst : clock_divider
    port map (
        clk_in  => clk,
        clk_out => clk_divided
    );

    -- UART RX Instance
    uart_rx_inst : uart_rx
    port map (
        clk     => clk_divided,
        rx      => uart_rx,
        data    => uart_data_out,
        valid   => uart_data_valid
    );

    -- Morse Encoder Instance
    morse_encoder_inst : morse_encoder
    port map (
        clk         => clk_divided,
        reset       => reset,
        char_in     => uart_data_out,
        morse_out   => morse_encoded,
        encoding_done => open
    );

    -- Morse Decoder Instance
    morse_decoder_inst : morse_decoder
    port map (
        clk         => clk_divided,
        reset       => reset,
        morse_in    => morse_encoded,
        char_out    => morse_decoded,
        valid       => open
    );

    -- FSM Controller Instance
    fsm_controller_inst : fsm_controller
    port map (
        clk             => clk_divided,
        reset           => reset,
        uart_data       => uart_data_out,
        uart_valid      => uart_data_valid,
        morse_encoded   => morse_encoded,
        morse_decoded   => morse_decoded,
        led_control     => led_output,
        buzzer_control  => buzzer
    );

end Behavioral;
