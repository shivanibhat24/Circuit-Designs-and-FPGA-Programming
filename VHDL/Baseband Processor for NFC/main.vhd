library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Baseband_Processor is
    Port (
        -- Clock and reset
        clk          : in  STD_LOGIC;
        rst          : in  STD_LOGIC;
        
        -- ADC interface
        adc_data_in  : in  STD_LOGIC_VECTOR(11 downto 0);
        adc_valid    : in  STD_LOGIC;
        
        -- DAC interface
        dac_data_out : out STD_LOGIC_VECTOR(11 downto 0);
        dac_valid    : out STD_LOGIC;
        
        -- Control interface
        filter_bypass : in  STD_LOGIC;
        agc_bypass    : in  STD_LOGIC;
        sync_detected : out STD_LOGIC;
        frame_valid   : out STD_LOGIC;
        frame_data    : out STD_LOGIC_VECTOR(7 downto 0);
        frame_error   : out STD_LOGIC
    );
end Baseband_Processor;

architecture Behavioral of BaseBand_Processor is
    -- Constants
    constant FIR_ORDER    : integer := 31;  -- FIR filter order (taps - 1)
    constant SYNC_WORD    : std_logic_vector(15 downto 0) := x"A5A5";  -- Sync word pattern
    constant AGC_TARGET   : unsigned(11 downto 0) := x"400";  -- Target signal level for AGC
    
    -- Internal signals
    signal filtered_data  : signed(15 downto 0);  -- FIR output with extended precision
    signal agc_data       : std_logic_vector(11 downto 0);  -- AGC output
    signal fir_valid      : std_logic;
    signal agc_valid      : std_logic;
    signal agc_gain       : unsigned(7 downto 0) := x"40";  -- Initial gain value
    
    -- Register to capture filtered data for packet decoder
    signal shift_reg      : std_logic_vector(31 downto 0);  -- Shift register for sync detection
    
    -- Components
    component FIR_Filter
        Port (
            clk           : in  STD_LOGIC;
            rst           : in  STD_LOGIC;
            data_in       : in  STD_LOGIC_VECTOR(11 downto 0);
            data_valid_in : in  STD_LOGIC;
            data_out      : out signed(15 downto 0);
            data_valid_out: out STD_LOGIC
        );
    end component;
    
    component AGC_Module
        Port (
            clk           : in  STD_LOGIC;
            rst           : in  STD_LOGIC;
            bypass        : in  STD_LOGIC;
            data_in       : in  signed(15 downto 0);
            data_valid_in : in  STD_LOGIC;
            target_level  : in  unsigned(11 downto 0);
            gain          : out unsigned(7 downto 0);
            data_out      : out STD_LOGIC_VECTOR(11 downto 0);
            data_valid_out: out STD_LOGIC
        );
    end component;
    
    component Packet_Decoder
        Port (
            clk           : in  STD_LOGIC;
            rst           : in  STD_LOGIC;
            data_in       : in  STD_LOGIC_VECTOR(11 downto 0);
            data_valid    : in  STD_LOGIC;
            sync_word     : in  STD_LOGIC_VECTOR(15 downto 0);
            sync_detected : out STD_LOGIC;
            frame_valid   : out STD_LOGIC;
            frame_data    : out STD_LOGIC_VECTOR(7 downto 0);
            frame_error   : out STD_LOGIC
        );
    end component;
    
begin
    -- Instantiate FIR Filter
    FIR_inst: FIR_Filter
    port map (
        clk            => clk,
        rst            => rst,
        data_in        => adc_data_in,
        data_valid_in  => adc_valid,
        data_out       => filtered_data,
        data_valid_out => fir_valid
    );
    
    -- Instantiate AGC Module
    AGC_inst: AGC_Module
    port map (
        clk            => clk,
        rst            => rst,
        bypass         => agc_bypass,
        data_in        => filtered_data,
        data_valid_in  => fir_valid,
        target_level   => AGC_TARGET,
        gain           => agc_gain,
        data_out       => agc_data,
        data_valid_out => agc_valid
    );
    
    -- Instantiate Packet Decoder
    Decoder_inst: Packet_Decoder
    port map (
        clk           => clk,
        rst           => rst,
        data_in       => agc_data,
        data_valid    => agc_valid,
        sync_word     => SYNC_WORD,
        sync_detected => sync_detected,
        frame_valid   => frame_valid,
        frame_data    => frame_data,
        frame_error   => frame_error
    );
    
    -- Connect the output
    dac_data_out <= agc_data;
    dac_valid <= agc_valid;

end Behavioral;

-- FIR Filter Implementation
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity FIR_Filter is
    Port (
        clk           : in  STD_LOGIC;
        rst           : in  STD_LOGIC;
        data_in       : in  STD_LOGIC_VECTOR(11 downto 0);
        data_valid_in : in  STD_LOGIC;
        data_out      : out signed(15 downto 0);
        data_valid_out: out STD_LOGIC
    );
end FIR_Filter;

architecture Behavioral of FIR_Filter is
    -- Constants
    constant FILTER_ORDER : integer := 31;
    
    -- Filter coefficient array (symmetric low-pass filter)
    type coefficient_array is array (0 to FILTER_ORDER) of signed(11 downto 0);
    constant COEFFS : coefficient_array := (
        x"021", x"02A", x"034", x"03F", x"049", x"053", x"05B", x"062",
        x"067", x"06A", x"06B", x"069", x"065", x"05E", x"054", x"048",
        x"048", x"054", x"05E", x"065", x"069", x"06B", x"06A", x"067",
        x"062", x"05B", x"053", x"049", x"03F", x"034", x"02A", x"021"
    );
    
    -- Data buffer for filter taps
    type shift_register_type is array (0 to FILTER_ORDER) of signed(11 downto 0);
    signal shift_reg : shift_register_type := (others => (others => '0'));
    
    -- Pipeline registers
    signal valid_pipeline : std_logic_vector(2 downto 0) := (others => '0');
    signal accumulator    : signed(27 downto 0);  -- Wide enough for worst-case accumulation
    
begin
    -- FIR filter process
    process(clk)
        variable acc : signed(27 downto 0);
        variable product : signed(23 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                shift_reg <= (others => (others => '0'));
                valid_pipeline <= (others => '0');
                data_out <= (others => '0');
                data_valid_out <= '0';
                accumulator <= (others => '0');
            else
                -- Shift register update
                if data_valid_in = '1' then
                    -- Shift in new data
                    for i in FILTER_ORDER downto 1 loop
                        shift_reg(i) <= shift_reg(i-1);
                    end loop;
                    shift_reg(0) <= signed(data_in);
                    
                    -- Start MAC operation
                    acc := (others => '0');
                    for i in 0 to FILTER_ORDER loop
                        product := shift_reg(i) * COEFFS(i);
                        acc := acc + product;
                    end loop;
                    
                    -- Pipeline the accumulation result
                    accumulator <= acc;
                    valid_pipeline(0) <= '1';
                else
                    valid_pipeline(0) <= '0';
                end if;
                
                -- Pipeline stages for valid signal
                valid_pipeline(1) <= valid_pipeline(0);
                valid_pipeline(2) <= valid_pipeline(1);
                
                -- Output scaling (take most significant bits)
                if valid_pipeline(1) = '1' then
                    -- Scale down by right shifting, preserving sign
                    data_out <= accumulator(27 downto 12);
                end if;
                
                -- Propagate valid signal to output
                data_valid_out <= valid_pipeline(2);
            end if;
        end if;
    end process;
end Behavioral;

-- Automatic Gain Control Module
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity AGC_Module is
    Port (
        clk           : in  STD_LOGIC;
        rst           : in  STD_LOGIC;
        bypass        : in  STD_LOGIC;
        data_in       : in  signed(15 downto 0);
        data_valid_in : in  STD_LOGIC;
        target_level  : in  unsigned(11 downto 0);
        gain          : out unsigned(7 downto 0);
        data_out      : out STD_LOGIC_VECTOR(11 downto 0);
        data_valid_out: out STD_LOGIC
    );
end AGC_Module;

architecture Behavioral of AGC_Module is
    -- Constants
    constant ATTACK_RATE  : unsigned(7 downto 0) := x"02";  -- Fast gain decrease for strong signals
    constant DECAY_RATE   : unsigned(7 downto 0) := x"01";  -- Slow gain increase for weak signals
    constant MAX_GAIN     : unsigned(7 downto 0) := x"FF";  -- Maximum gain setting
    constant MIN_GAIN     : unsigned(7 downto 0) := x"10";  -- Minimum gain setting
    
    -- Signals
    signal current_gain   : unsigned(7 downto 0) := x"40";  -- Initial gain value
    signal abs_input      : unsigned(15 downto 0);
    signal peak_detector  : unsigned(15 downto 0) := (others => '0');
    signal gain_applied   : signed(23 downto 0);  -- Wide enough for gain multiplication
    
    -- Averaging counter for peak detector
    signal avg_counter    : unsigned(7 downto 0) := (others => '0');
    signal update_gain    : std_logic := '0';
    
begin
    -- Calculate absolute value of input
    abs_input <= unsigned(abs(data_in));
    
    -- Peak detector process
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                peak_detector <= (others => '0');
                avg_counter <= (others => '0');
                update_gain <= '0';
            elsif data_valid_in = '1' then
                -- Update peak value if current sample is larger
                if abs_input > peak_detector then
                    peak_detector <= abs_input;
                end if;
                
                -- Increment counter
                if avg_counter = 255 then  -- Process every 256 samples
                    avg_counter <= (others => '0');
                    update_gain <= '1';
                else
                    avg_counter <= avg_counter + 1;
                    update_gain <= '0';
                end if;
            end if;
        end if;
    end process;
    
    -- Gain control logic
    process(clk)
        variable scaled_peak : unsigned(23 downto 0);
        variable target_scaled : unsigned(23 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                current_gain <= x"40";  -- Reset to initial gain value
            elsif update_gain = '1' and bypass = '0' then
                -- Scale peak by current gain
                scaled_peak := peak_detector * current_gain;
                
                -- Scale target for comparison
                target_scaled := target_level & x"000";  -- Shift left by 12 bits
                
                -- Compare scaled peak with target
                if scaled_peak > target_scaled then
                    -- Signal too strong, decrease gain (don't go below minimum)
                    if current_gain > (MIN_GAIN + ATTACK_RATE) then
                        current_gain <= current_gain - ATTACK_RATE;
                    else
                        current_gain <= MIN_GAIN;
                    end if;
                elsif scaled_peak < (target_scaled srl 1) then  -- Less than half target
                    -- Signal too weak, increase gain (don't exceed maximum)
                    if current_gain < (MAX_GAIN - DECAY_RATE) then
                        current_gain <= current_gain + DECAY_RATE;
                    else
                        current_gain <= MAX_GAIN;
                    end if;
                end if;
                
                -- Reset peak detector for next cycle
                peak_detector <= (others => '0');
            end if;
        end if;
    end process;
    
    -- Apply gain to input signal
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                gain_applied <= (others => '0');
                data_out <= (others => '0');
                data_valid_out <= '0';
            else
                -- Apply gain
                if bypass = '1' then
                    -- Bypass mode - just pass through with truncation/extension
                    data_out <= std_logic_vector(data_in(15 downto 4));
                else
                    -- Apply gain
                    gain_applied <= data_in * signed('0' & current_gain);
                    
                    -- Saturate output if needed
                    if gain_applied > 2047 then
                        data_out <= x"7FF";  -- Max positive value
                    elsif gain_applied < -2048 then
                        data_out <= x"800";  -- Max negative value
                    else
                        -- Scale to 12 bits, taking middle bits of result
                        data_out <= std_logic_vector(gain_applied(19 downto 8));
                    end if;
                end if;
                
                -- Pass through valid signal
                data_valid_out <= data_valid_in;
            end if;
        end if;
    end process;
    
    -- Output current gain value
    gain <= current_gain;
    
end Behavioral;

-- Packet Decoder
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Packet_Decoder is
    Port (
        clk           : in  STD_LOGIC;
        rst           : in  STD_LOGIC;
        data_in       : in  STD_LOGIC_VECTOR(11 downto 0);
        data_valid    : in  STD_LOGIC;
        sync_word     : in  STD_LOGIC_VECTOR(15 downto 0);
        sync_detected : out STD_LOGIC;
        frame_valid   : out STD_LOGIC;
        frame_data    : out STD_LOGIC_VECTOR(7 downto 0);
        frame_error   : out STD_LOGIC
    );
end Packet_Decoder;

architecture Behavioral of Packet_Decoder is
    -- Constants
    constant FRAME_LENGTH : integer := 32;  -- Frame length in bytes
    constant THRESHOLD    : integer := 4;   -- Bit error threshold for sync detection
    
    -- State machine
    type state_type is (IDLE, SYNC_SEARCH, RECEIVING_LENGTH, RECEIVING_DATA, RECEIVING_CRC);
    signal state : state_type := IDLE;
    
    -- Bit and byte processing
    signal bit_counter    : integer range 0 to 7 := 0;
    signal byte_counter   : integer range 0 to 255 := 0;
    signal frame_length   : integer range 0 to 255 := 0;
    signal received_byte  : std_logic_vector(7 downto 0) := (others => '0');
    
    -- Shift register for bit detection
    signal bit_shift_reg  : std_logic_vector(23 downto 0) := (others => '0');
    signal sync_shift_reg : std_logic_vector(31 downto 0) := (others => '0');
    
    -- CRC calculation
    signal crc            : std_logic_vector(15 downto 0) := (others => '0');
    signal calc_crc       : std_logic_vector(15 downto 0) := (others => '0');
    
    -- Bit slicing function - convert analog value to binary
    function slice_bit(analog_in : std_logic_vector(11 downto 0)) return std_logic is
    begin
        if signed(analog_in) >= 0 then
            return '1';
        else
            return '0';
        end if;
    end function;
    
    -- Function to count bit errors in sync word
    function count_errors(reg_in : std_logic_vector; sync_in : std_logic_vector) return integer is
        variable count : integer := 0;
    begin
        for i in 0 to 15 loop
            if reg_in(i) /= sync_in(i) then
                count := count + 1;
            end if;
        end loop;
        return count;
    end function;
    
    -- CRC-16 calculation function
    function update_crc(current_crc : std_logic_vector(15 downto 0); 
                       data_in : std_logic_vector(7 downto 0)) return std_logic_vector is
        variable crc_temp : std_logic_vector(15 downto 0);
        variable next_bit : std_logic;
    begin
        crc_temp := current_crc;
        
        for i in 0 to 7 loop
            next_bit := data_in(i) xor crc_temp(15);
            crc_temp := crc_temp(14 downto 0) & '0';
            
            if next_bit = '1' then
                crc_temp := crc_temp xor x"1021";  -- CRC-16-CCITT polynomial
            end if;
        end loop;
        
        return crc_temp;
    end function;
    
begin
    -- Main packet decoder process
    process(clk)
        variable bit_value : std_logic;
        variable error_count : integer;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= IDLE;
                bit_counter <= 0;
                byte_counter <= 0;
                frame_length <= 0;
                received_byte <= (others => '0');
                bit_shift_reg <= (others => '0');
                sync_shift_reg <= (others => '0');
                crc <= (others => '0');
                calc_crc <= (others => '0');
                sync_detected <= '0';
                frame_valid <= '0';
                frame_data <= (others => '0');
                frame_error <= '0';
            elsif data_valid = '1' then
                -- Default outputs
                sync_detected <= '0';
                frame_valid <= '0';
                frame_error <= '0';
                
                -- Extract bit from analog sample
                bit_value := slice_bit(data_in);
                
                -- Update bit shift register
                bit_shift_reg <= bit_shift_reg(22 downto 0) & bit_value;
                
                -- State machine for packet decoding
                case state is
                    when IDLE =>
                        -- Update sync word detection register
                        sync_shift_reg <= sync_shift_reg(30 downto 0) & bit_value;
                        
                        -- Check if sync word is found with allowed bit errors
                        error_count := count_errors(sync_shift_reg(15 downto 0), sync_word);
                        
                        if error_count <= THRESHOLD then
                            -- Sync word detected
                            sync_detected <= '1';
                            state <= RECEIVING_LENGTH;
                            bit_counter <= 0;
                            byte_counter <= 0;
                            received_byte <= (others => '0');
                            calc_crc <= (others => '1');  -- Initialize CRC
                        end if;
                        
                    when RECEIVING_LENGTH =>
                        -- Capture frame length byte
                        received_byte <= received_byte(6 downto 0) & bit_value;
                        
                        if bit_counter = 7 then
                            -- Full byte received
                            bit_counter <= 0;
                            frame_length <= to_integer(unsigned(received_byte(6 downto 0) & bit_value));
                            state <= RECEIVING_DATA;
                            
                            -- Update CRC with length byte
                            calc_crc <= update_crc(calc_crc, received_byte(6 downto 0) & bit_value);
                        else
                            bit_counter <= bit_counter + 1;
                        end if;
                        
                    when RECEIVING_DATA =>
                        -- Capture data byte
                        received_byte <= received_byte(6 downto 0) & bit_value;
                        
                        if bit_counter = 7 then
                            -- Full byte received
                            bit_counter <= 0;
                            frame_valid <= '1';
                            frame_data <= received_byte(6 downto 0) & bit_value;
                            
                            -- Update CRC
                            calc_crc <= update_crc(calc_crc, received_byte(6 downto 0) & bit_value);
                            
                            -- Check if we've received all data bytes
                            if byte_counter = frame_length - 1 then
                                byte_counter <= 0;
                                state <= RECEIVING_CRC;
                            else
                                byte_counter <= byte_counter + 1;
                            end if;
                        else
                            bit_counter <= bit_counter + 1;
                        end if;
                        
                    when RECEIVING_CRC =>
                        -- Capture CRC bytes
                        received_byte <= received_byte(6 downto 0) & bit_value;
                        
                        if bit_counter = 7 then
                            -- Full byte received
                            if byte_counter = 0 then
                                -- First CRC byte
                                crc(15 downto 8) <= received_byte(6 downto 0) & bit_value;
                                byte_counter <= 1;
                                bit_counter <= 0;
                            else
                                -- Second CRC byte, verify packet
                                crc(7 downto 0) <= received_byte(6 downto 0) & bit_value;
                                
                                -- Check if CRC matches
                                if calc_crc = (received_byte(6 downto 0) & bit_value & crc(15 downto 8)) then
                                    frame_error <= '0';
                                else
                                    frame_error <= '1';
                                end if;
                                
                                -- Go back to IDLE state
                                state <= IDLE;
                            end if;
                        else
                            bit_counter <= bit_counter + 1;
                        end if;
                end case;
            end if;
        end if;
    end process;
end Behavioral;
