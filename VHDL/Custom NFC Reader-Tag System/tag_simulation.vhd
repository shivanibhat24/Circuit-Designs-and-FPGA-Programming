library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity nfc_tag_sim is
    Port (
        clk            : in  STD_LOGIC;
        rst            : in  STD_LOGIC;
        carrier_detect : in  STD_LOGIC;
        reader_mod     : in  STD_LOGIC;
        tag_id         : in  STD_LOGIC_VECTOR(31 downto 0);
        load_mod_out   : out STD_LOGIC
    );
end nfc_tag_sim;

architecture Behavioral of nfc_tag_sim is
    -- Tag state machine
    type tag_state_type is (POWERED_OFF, IDLE, RECEIVING, PROCESSING, SENDING);
    signal tag_state : tag_state_type := POWERED_OFF;
    
    -- Internal signals
    signal bit_counter    : integer range 0 to 7 := 0;
    signal rx_shift_reg   : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal tx_shift_reg   : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal cycle_counter  : integer range 0 to 255 := 0;
    signal command_received : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal load_mod       : STD_LOGIC := '0';
    
    -- NFC Tag commands
    constant CMD_REQA    : STD_LOGIC_VECTOR(7 downto 0) := x"26"; -- REQA command
    constant CMD_WUPA    : STD_LOGIC_VECTOR(7 downto 0) := x"52"; -- WUPA command
    constant CMD_ANTICOL : STD_LOGIC_VECTOR(7 downto 0) := x"93"; -- Anti-collision command
    constant ATQA_RESP   : STD_LOGIC_VECTOR(7 downto 0) := x"44"; -- ATQA response
begin
    -- Tag state machine process
    process(clk, rst)
    begin
        if rst = '1' then
            tag_state <= POWERED_OFF;
            bit_counter <= 0;
            rx_shift_reg <= (others => '0');
            tx_shift_reg <= (others => '0');
            cycle_counter <= 0;
            command_received <= (others => '0');
            load_mod <= '0';
        elsif rising_edge(clk) then
            -- Default assignment
            load_mod <= '0';
            
            case tag_state is
                when POWERED_OFF =>
                    -- Tag is powered off
                    if carrier_detect = '1' then
                        tag_state <= IDLE;
                    end if;
                
                when IDLE =>
                    -- Tag is powered and waiting for command
                    if carrier_detect = '0' then
                        tag_state <= POWERED_OFF;
                    elsif reader_mod = '0' then
                        -- Start receiving command
                        tag_state <= RECEIVING;
                        bit_counter <= 0;
                        cycle_counter <= 0;
                        rx_shift_reg <= (others => '0');
                    end if;
                
                when RECEIVING =>
                    -- Receiving command from reader
                    if carrier_detect = '0' then
                        tag_state <= POWERED_OFF;
                    else
                        -- Sample reader modulation
                        if cycle_counter = 64 then -- Mid-bit sample point
                            rx_shift_reg <= rx_shift_reg(6 downto 0) & reader_mod;
                        end if;
                        
                        if cycle_counter < 127 then
                            cycle_counter <= cycle_counter + 1;
                        else
                            cycle_counter <= 0;
                            if bit_counter < 7 then
                                bit_counter <= bit_counter + 1;
                            else
                                -- Complete byte received
                                command_received <= rx_shift_reg;
                                tag_state <= PROCESSING;
                            end if;
                        end if;
                    end if;
                
                when PROCESSING =>
                    -- Process received command
                    if carrier_detect = '0' then
                        tag_state <= POWERED_OFF;
                    else
                        -- Prepare response based on command
                        case command_received is
                            when CMD_REQA | CMD_WUPA =>
                                tx_shift_reg <= ATQA_RESP;
                                tag_state <= SENDING;
                                bit_counter <= 0;
                                cycle_counter <= 0;
                            
                            when CMD_ANTICOL =>
                                -- Respond with first byte of tag ID
                                tx_shift_reg <= tag_id(7 downto 0);
                                tag_state <= SENDING;
                                bit_counter <= 0;
                                cycle_counter <= 0;
                            
                            when others =>
                                -- Unknown command, return to idle
                                tag_state <= IDLE;
                        end case;
                    end if;
                
                when SENDING =>
                    -- Sending response to reader
                    if carrier_detect = '0' then
                        tag_state <= POWERED_OFF;
                    else
                        -- Generate load modulation based on current bit
                        if tx_shift_reg(bit_counter) = '1' then
                            -- Manchester encoding for '1': transition at mid-bit
                            if cycle_counter < 64 then
                                load_mod <= '0';
                            else
                                load_mod <= '1';
                            end if;
                        else
                            -- Manchester encoding for '0': transition at mid-bit
                            if cycle_counter < 64 then
                                load_mod <= '1';
                            else
                                load_mod <= '0';
                            end if;
                        end if;
                        
                        -- Bit timing
                        if cycle_counter < 127 then
                            cycle_counter <= cycle_counter + 1;
                        else
                            cycle_counter <= 0;
                            if bit_counter < 7 then
                                bit_counter <= bit_counter + 1;
                            else
                                -- Complete byte sent
                                tag_state <= IDLE;
                            end if;
                        end if;
                    end if;
                
                when others =>
                    tag_state <= POWERED_OFF;
            end case;
        end if;
    end process;
    
    -- Output assignment
    load_mod_out <= load_mod;
end Behavioral;
