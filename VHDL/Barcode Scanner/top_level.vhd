library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top_level is
    Port ( 
        -- System Signals
        clk_in     : in STD_LOGIC;
        reset      : in STD_LOGIC;
        
        -- Camera Interface
        cam_data   : in STD_LOGIC_VECTOR(7 downto 0);
        cam_valid  : in STD_LOGIC;
        
        -- UART Transmit
        uart_tx    : out STD_LOGIC;
        
        -- Debug Outputs
        led_status : out STD_LOGIC_VECTOR(3 downto 0)
    );
end top_level;

architecture Behavioral of top_level is
    -- Internal Signals
    signal clk_proc     : STD_LOGIC;
    signal clk_uart     : STD_LOGIC;
    signal reset_sync   : STD_LOGIC;
    
    -- Signals between modules
    signal gray_data    : STD_LOGIC_VECTOR(7 downto 0);
    signal edge_data    : STD_LOGIC_VECTOR(7 downto 0);
    signal binary_data  : STD_LOGIC;
    signal barcode_data : STD_LOGIC_VECTOR(31 downto 0);
    signal decode_valid : STD_LOGIC;

begin
    -- Clock Divider
    clk_div_inst : entity work.clock_divider
    port map (
        clk_in      => clk_in,
        reset       => reset,
        clk_proc    => clk_proc,
        clk_uart    => clk_uart
    );

    -- Image Capture
    img_capture_inst : entity work.image_capture
    port map (
        clk         => clk_proc,
        reset       => reset_sync,
        cam_data    => cam_data,
        cam_valid   => cam_valid,
        gray_data   => gray_data
    );

    -- Grayscale Converter
    gray_conv_inst : entity work.grayscale_converter
    port map (
        clk         => clk_proc,
        reset       => reset_sync,
        rgb_data    => cam_data,
        gray_data   => gray_data
    );

    -- Edge Detection
    edge_detect_inst : entity work.edge_detection
    port map (
        clk         => clk_proc,
        reset       => reset_sync,
        gray_data   => gray_data,
        edge_data   => edge_data
    );

    -- Binarization
    binarize_inst : entity work.binarization
    port map (
        clk         => clk_proc,
        reset       => reset_sync,
        gray_data   => gray_data,
        binary_data => binary_data
    );

    -- Barcode Detection
    barcode_detect_inst : entity work.barcode_detection
    port map (
        clk         => clk_proc,
        reset       => reset_sync,
        binary_data => binary_data,
        barcode_detected => led_status(0)
    );

    -- Decoder
    decoder_inst : entity work.decoder
    port map (
        clk         => clk_proc,
        reset       => reset_sync,
        binary_data => binary_data,
        decoded_data=> barcode_data,
        valid_out   => decode_valid
    );

    -- UART Transmitter
    uart_tx_inst : entity work.uart_transmitter
    port map (
        clk         => clk_uart,
        reset       => reset_sync,
        data_in     => barcode_data,
        valid_in    => decode_valid,
        tx_out      => uart_tx
    );

    -- Status LED Management
    process(clk_proc)
    begin
        if rising_edge(clk_proc) then
            if reset = '1' then
                reset_sync <= '1';
                led_status <= (others => '0');
            else
                reset_sync <= '0';
                led_status(3 downto 1) <= (others => decode_valid);
            end if;
        end if;
    end process;
end Behavioral;
