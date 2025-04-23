library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity modulator is
    Port (
        clk          : in  STD_LOGIC;
        rst          : in  STD_LOGIC;
        enable       : in  STD_LOGIC;
        data_in      : in  STD_LOGIC_VECTOR(7 downto 0);
        modulation   : out STD_LOGIC
    );
end modulator;

architecture Behavioral of modulator is
    -- Constants for ASK modulation (10% ASK)
    constant BIT_PERIOD : integer := 128; -- Bit period in carrier cycles (for 106 kbps)
    
    -- States for the modulator FSM
    type mod_state_type is (IDLE, SENDING, BIT_PAUSE);
    signal mod_state : mod_state_type := IDLE;
    
    -- Internal signals
    signal bit_counter     : integer range 0 to 7 := 0;
    signal cycle_counter   : integer range 0 to BIT_PERIOD-1 := 0;
    signal current_bit     : STD_LOGIC := '0';
    signal mod_output      : STD_LOGIC := '1'; -- Active low modulation
begin
    -- ASK modulation process
    process(clk, rst)
    begin
        if rst = '1' then
            mod_state <= IDLE;
            bit_counter <= 0;
            cycle_counter <= 0;
            mod_output <= '1'; -- No modulation
        elsif rising_edge(clk) then
            case mod_state is
                when IDLE =>
                    mod_output <= '1'; -- No modulation
                    if enable = '1' then
                        mod_state <= SENDING;
                        bit_counter <= 0;
                        cycle_counter <= 0;
                        current_bit <= data_in(0); -- LSB first
                    end if;
                
                when SENDING =>
                    -- Determine output based on current bit
                    if current_bit = '1' then
                        mod_output <= '1'; -- No modulation for '1'
                    else
                        mod_output <= '0'; -- 100% modulation for '0'
                    end if;
                    
                    -- Count cycles for bit timing
                    if cycle_counter < BIT_PERIOD-1 then
                        cycle_counter <= cycle_counter + 1;
                    else
                        cycle_counter <= 0;
                        -- Move to next bit
                        if bit_counter < 7 then
                            bit_counter <= bit_counter + 1;
                            current_bit <= data_in(bit_counter + 1);
                            mod_state <= BIT_PAUSE;
                        else
                            -- All bits sent
                            mod_state <= IDLE;
                        end if;
                    end if;
                
                when BIT_PAUSE =>
                    -- Small pause between bits
                    mod_output <= '1'; -- No modulation during pause
                    mod_state <= SENDING;
                    
                when others =>
                    mod_state <= IDLE;
            end case;
            
            -- Disable modulation if enable goes low
            if enable = '0' then
                mod_state <= IDLE;
                mod_output <= '1'; -- No modulation
            end if;
        end if;
    end process;
    
    modulation <= mod_output;
end Behavioral;
