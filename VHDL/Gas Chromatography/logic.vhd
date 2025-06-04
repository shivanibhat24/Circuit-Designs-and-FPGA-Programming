-- Sensor Readout Sequencer
-- Handles timing and sequencing for multiple gas sensors

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gc_package.all;

entity sensor_sequencer is
    port (
        clk             : in  std_logic;
        rst_n           : in  std_logic;
        enable          : in  std_logic;
        
        -- Control interface
        start_sequence  : in  std_logic;
        sequence_done   : out std_logic;
        current_sensor  : out std_logic_vector(log2_ceil(NUM_SENSORS)-1 downto 0);
        
        -- ADC interface
        adc_cs_n        : out std_logic;
        adc_sclk        : out std_logic;
        adc_mosi        : out std_logic;
        adc_miso        : in  std_logic;
        adc_conv_start  : out std_logic;
        adc_busy        : in  std_logic;
        
        -- Sensor multiplexer control
        sensor_select   : out std_logic_vector(log2_ceil(NUM_SENSORS)-1 downto 0);
        sensor_enable   : out std_logic;
        
        -- Data output
        sensor_data     : out sensor_array_t;
        data_valid      : out std_logic;
        sensor_ready    : out std_logic
    );
end entity sensor_sequencer;

architecture rtl of sensor_sequencer is
    
    -- Internal signals
    signal state            : sensor_seq_state_t;
    signal next_state       : sensor_seq_state_t;
    signal sensor_counter   : unsigned(log2_ceil(NUM_SENSORS)-1 downto 0);
    signal settle_counter   : unsigned(15 downto 0);
    signal spi_counter      : unsigned(4 downto 0);
    signal shift_reg        : std_logic_vector(15 downto 0);
    signal sample_counter   : unsigned(15 downto 0);
    
    -- Timing constants
    constant SETTLE_TIME    : integer := 1000;  -- Sensor settling time (10us @ 100MHz)
    constant SAMPLE_PERIOD  : integer := CLOCK_FREQ / (SAMPLE_RATE * NUM_SENSORS);
    
    -- Internal data storage
    signal sensor_data_int  : sensor_array_t;
    signal conversion_done  : std_logic;
    signal spi_busy         : std_logic;
    
begin
    
    -- State machine process
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            state <= SEQ_IDLE;
            sensor_counter <= (others => '0');
            settle_counter <= (others => '0');
            spi_counter <= (others => '0');
            shift_reg <= (others => '0');
            sample_counter <= (others => '0');
            sensor_data_int <= (others => (others => '0'));
            conversion_done <= '0';
            spi_busy <= '0';
        elsif rising_edge(clk) then
            state <= next_state;
            
            case state is
                when SEQ_IDLE =>
                    sensor_counter <= (others => '0');
                    settle_counter <= (others => '0');
                    conversion_done <= '0';
                    
                when SEQ_SELECT =>
                    settle_counter <= (others => '0');
                    
                when SEQ_SETTLE =>
                    if settle_counter < SETTLE_TIME then
                        settle_counter <= settle_counter + 1;
                    end if;
                    
                when SEQ_CONVERT =>
                    if not spi_busy then
                        spi_counter <= (others => '0');
                        shift_reg <= (others => '0');
                        spi_busy <= '1';
                    elsif spi_counter < 16 then
                        spi_counter <= spi_counter + 1;
                        shift_reg <= shift_reg(14 downto 0) & adc_miso;
                    else
                        spi_busy <= '0';
                        conversion_done <= '1';
                        sensor_data_int(to_integer(sensor_counter)) <= 
                            shift_reg(ADC_RESOLUTION-1 downto 0);
                    end if;
                    
                when SEQ_READ =>
                    conversion_done <= '0';
                    
                when SEQ_NEXT =>
                    if sensor_counter < NUM_SENSORS - 1 then
                        sensor_counter <= sensor_counter + 1;
                    else
                        sensor_counter <= (others => '0');
                    end if;
                    
                when others =>
                    null;
            end case;
            
            -- Sample timing counter
            if sample_counter < SAMPLE_PERIOD then
                sample_counter <= sample_counter + 1;
            else
                sample_counter <= (others => '0');
            end if;
        end if;
    end process;
    
    -- Next state logic
    process(state, enable, start_sequence, settle_counter, adc_busy, 
            conversion_done, sensor_counter, sample_counter)
    begin
        next_state <= state;
        
        case state is
            when SEQ_IDLE =>
                if enable = '1' and start_sequence = '1' then
                    next_state <= SEQ_SELECT;
                end if;
                
            when SEQ_SELECT =>
                next_state <= SEQ_SETTLE;
                
            when SEQ_SETTLE =>
                if settle_counter >= SETTLE_TIME then
                    next_state <= SEQ_CONVERT;
                end if;
                
            when SEQ_CONVERT =>
                if conversion_done = '1' then
                    next_state <= SEQ_READ;
                end if;
                
            when SEQ_READ =>
                next_state <= SEQ_NEXT;
                
            when SEQ_NEXT =>
                if sensor_counter = NUM_SENSORS - 1 then
                    if sample_counter >= SAMPLE_PERIOD then
                        next_state <= SEQ_SELECT;
                    else
                        next_state <= SEQ_IDLE;
                    end if;
                else
                    next_state <= SEQ_SELECT;
                end if;
                
            when others =>
                next_state <= SEQ_IDLE;
        end case;
    end process;
    
    -- SPI control logic
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            adc_cs_n <= '1';
            adc_sclk <= '0';
            adc_mosi <= '0';
            adc_conv_start <= '0';
        elsif rising_edge(clk) then
            case state is
                when SEQ_CONVERT =>
                    if spi_busy then
                        adc_cs_n <= '0';
                        if spi_counter(0) = '0' then
                            adc_sclk <= '0';
                        else
                            adc_sclk <= '1';
                        end if;
                        adc_conv_start <= '1';
                    else
                        adc_cs_n <= '1';
                        adc_sclk <= '0';
                        adc_conv_start <= '0';
                    end if;
                    
                when others =>
                    adc_cs_n <= '1';
                    adc_sclk <= '0';
                    adc_mosi <= '0';
                    adc_conv_start <= '0';
            end case;
        end if;
    end process;
    
    -- Output assignments
    sensor_select <= std_logic_vector(sensor_counter);
    current_sensor <= std_logic_vector(sensor_counter);
    sensor_enable <= '1' when state = SEQ_SETTLE or state = SEQ_CONVERT else '0';
    
    sensor_data <= sensor_data_int;
    data_valid <= '1' when state = SEQ_READ else '0';
    sensor_ready <= '1' when state = SEQ_IDLE else '0';
    sequence_done <= '1' when state = SEQ_NEXT and sensor_counter = NUM_SENSORS - 1 else '0';
    
end architecture rtl;
