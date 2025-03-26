library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity decoder is
    Port ( 
        clk         : in STD_LOGIC;
        reset       : in STD_LOGIC;
        binary_data : in STD_LOGIC;
        barcode_type: in STD_LOGIC_VECTOR(3 downto 0);
        decoded_data: out STD_LOGIC_VECTOR(31 downto 0);
        valid_out   : out STD_LOGIC
    );
end decoder;

architecture Behavioral of decoder is
    -- Decoding state machine
    type decode_state is (IDLE, START, DECODE_DIGIT, VALIDATE, COMPLETE);
    signal current_state : decode_state := IDLE;

    -- Decoding parameters
    constant EAN13_DIGIT_WIDTH : integer := 7;
    constant UPCA_DIGIT_WIDTH  : integer := 7;

    -- Decoding buffers
    signal digit_buffer    : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
    signal current_digit   : integer range 0 to 15 := 0;
    signal bit_count       : integer range 0 to 255 := 0;

    -- EAN-13 and UPC-A digit decoding LUT
    type digit_lut is array(0 to 9) of STD_LOGIC_VECTOR(6 downto 0);
    constant EAN13_ENCODE : digit_lut := (
        "1110010", "1100110", "1101100", "1000010", "1011100",
        "1001110", "1010000", "1000100", "1001000", "1110100"
    );
    constant UPCA_ENCODE : digit_lut := (
        "0001101", "0011001", "0010011", "0111101", "0100011",
        "0110001", "0101111", "0111011", "0110111", "0001011"
    );

begin
    process(clk, reset)
        variable matched_digit : integer range 0 to 9;
    begin
        if reset = '1' then
            current_state <= IDLE;
            digit_buffer <= (others => '0');
            current_digit <= 0;
            bit_count <= 0;
            valid_out <= '0';
        elsif rising_edge(clk) then
            case current_state is
                when IDLE =>
                    -- Wait for barcode detection
                    if barcode_type /= "0000" then
                        current_state <= START;
                        digit_buffer <= (others => '0');
                    end if;

                when START =>
                    -- Begin decoding process
                    bit_count <= 0;
                    current_digit <= 0;
                    current_state <= DECODE_DIGIT;

                when DECODE_DIGIT =>
                    -- Accumulate bits for current digit
                    digit_buffer(bit_count) <= binary_data;
                    bit_count <= bit_count + 1;

                    -- Check for full digit width
                    if bit_count = EAN13_DIGIT_WIDTH - 1 then
                        -- Match against lookup tables
                        matched_digit := 0;
                        for i in 0 to 9 loop
                            if barcode_type = "0001" and 
                               digit_buffer(6 downto 0) = EAN13_ENCODE(i) then
                                matched_digit := i;
                                exit;
                            elsif barcode_type = "0010" and 
                                  digit_buffer(6 downto 0) = UPCA_ENCODE(i) then
                                matched_digit := i;
                                exit;
                            end if;
                        end loop;

                        -- Store decoded digit
                        decoded_data(current_digit*4+3 downto current_digit*4) <= 
                            std_logic_vector(to_unsigned(matched_digit, 4));
                        
                        -- Move to next digit
                        current_digit <= current_digit + 1;
                        bit_count <= 0;

                        -- Check total digits
                        if current_digit = 12 then
                            current_state <= VALIDATE;
                        end if;
                    end if;

                when VALIDATE =>
                    -- Perform checksum validation
                    -- For EAN-13 and UPC-A, different checksum algorithms
                    if barcode_type = "0001" then
                        -- EAN-13 validation logic
                        -- More complex checksum calculation
                    elsif barcode_type = "0010" then
                        -- UPC-A validation logic
                    end if;

                    valid_out <= '1';
                    current_state <= COMPLETE;

                when COMPLETE =>
                    -- Hold decoded data briefly
                    valid_out <= '0';
                    current_state <= IDLE;
            end case;
        end if;
    end process;
end Behavioral;
