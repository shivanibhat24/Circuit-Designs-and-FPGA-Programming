library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity demodulator is
    Port (
        clk          : in  STD_LOGIC;
        rst          : in  STD_LOGIC;
        load_mod_in  : in  STD_LOGIC;
        data_out     : out STD_LOGIC_VECTOR(7 downto 0);
        data_valid   : out STD_LOGIC
    );
end demodulator;

architecture Behavioral of demodulator is
    -- Constants for demodulation
    constant BIT_PERIOD : integer := 128; -- Bit period in carrier cycles (for 106 kbps)
    constant SAMPLE_POINT : integer := BIT_PERIOD / 2; -- Sample in middle of bit
    
    -- States for the demodulator FSM
    type demod_state_type is (WAITING, SYNCING, RECEIVING);
    signal demod_state : demod_state_type := WAITING;
    
    -- Internal signals
    signal bit_counter     : integer range 0 to 7 := 0;
    signal cycle_counter   : integer range 0 to BIT_PERIOD-1 := 0;
    signal rx_shift_reg    : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal data_valid_int  : STD_LOGIC := '0';
    signal prev_load_mod   : STD_LOGIC := '0';
    signal edge_detected   : STD_LOGIC := '0';
begin
    -- Load modulation detection and bit decoding
    process(clk, rst)
    begin
        if rst = '1' then
            demod_state <= WAITING;
            bit_counter <= 0;
            cycle_counter <= 0;
            rx_shift_reg <= (others => '0');
            data_valid_int <= '0';
            prev_load_mod <= '0';
            edge_detected <= '0';
        elsif rising_edge(clk) then
            -- Edge detection
            prev_load_mod <= load_mod_in;
            edge_detected <= '0';
            
            if load_mod_in /= prev_load_mod then
                edge_detected <= '1';
            end if;
            
            -- Default for data_valid
            data_valid_int <= '0';
            
            case demod_state is
                when WAITING =>
                    -- Wait for start of transmission (SOF)
                    if edge_detected = '1' then
                        demod_state <= SYNCING;
                        cycle_counter <= 0;
                    end if;
                
                when SYNCING =>
                    -- Synchronize with incoming bit stream
                    cycle_counter <= cycle_counter + 1;
                    if cycle_counter = BIT_PERIOD - 1 then
                        demod_state <= RECEIVING;
                        bit_counter <= 0;
                        cycle_counter <= 0;
                    end if;
                
                when RECEIVING =>
                    -- Sample each bit at the midpoint
                    cycle_counter <= cycle_counter + 1;
                    
                    if cycle_counter = SAMPLE_POINT then
                        -- Sample the bit
                        rx_shift_reg <= rx_shift_reg(6 downto 0) & load_mod_in;
                    end if;
                    
                    if cycle_counter = BIT_PERIOD - 1 then
                        cycle_counter <= 0;
                        if bit_counter < 7 then
                            bit_counter <= bit_counter + 1;
                        else
                            -- All bits received
                            data_valid_int <= '1';
                            demod_state <= WAITING;
                        end if;
                    end if;
                    
                when others =>
                    demod_state <= WAITING;
            end case;
        end if;
    end process;
    
    -- Output assignments
    data_out <= rx_shift_reg;
    data_valid <= data_valid_int;
end Behavioral;
