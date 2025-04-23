library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity protocol_controller is
    Port (
        clk              : in  STD_LOGIC;
        rst              : in  STD_LOGIC;
        start_trans      : in  STD_LOGIC;
        command          : in  STD_LOGIC_VECTOR(7 downto 0);
        data_to_send     : in  STD_LOGIC_VECTOR(7 downto 0);
        field_detect     : in  STD_LOGIC;
        data_received    : in  STD_LOGIC_VECTOR(7 downto 0);
        data_valid_in    : in  STD_LOGIC;
        carrier_enable   : out STD_LOGIC;
        mod_enable       : out STD_LOGIC;
        tx_data          : out STD_LOGIC_VECTOR(7 downto 0);
        data_ready_out   : out STD_LOGIC;
        data_out         : out STD_LOGIC_VECTOR(7 downto 0)
    );
end protocol_controller;

architecture Behavioral of protocol_controller is
    -- NFC Protocol Constants
    constant CMD_REQA    : STD_LOGIC_VECTOR(7 downto 0) := x"26"; -- REQA command
    constant CMD_WUPA    : STD_LOGIC_VECTOR(7 downto 0) := x"52"; -- WUPA command
    constant CMD_ANTICOL : STD_LOGIC_VECTOR(7 downto 0) := x"93"; -- Anti-collision command
    constant CMD_SELECT  : STD_LOGIC_VECTOR(7 downto 0) := x"95"; -- Select command
    constant CMD_HALT    : STD_LOGIC_VECTOR(7 downto 0) := x"50"; -- Halt command
    
    -- Protocol state machine
    type protocol_state_type is (IDLE, FIELD_ON, SEND_COMMAND, WAIT_RESPONSE, 
                                 PROCESS_RESPONSE, FIELD_OFF);
    signal protocol_state : protocol_state_type := IDLE;
    
    -- Internal signals
    signal timeout_counter   : integer range 0 to 10000 := 0;
    signal response_received : STD_LOGIC := '0';
    signal current_command   : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal output_data       : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal data_ready        : STD_LOGIC := '0';
begin
    -- Protocol state machine process
    process(clk, rst)
    begin
        if rst = '1' then
            protocol_state <= IDLE;
            carrier_enable <= '0';
            mod_enable <= '0';
            tx_data <= (others => '0');
            timeout_counter <= 0;
            response_received <= '0';
            current_command <= (others => '0');
            output_data <= (others => '0');
            data_ready <= '0';
        elsif rising_edge(clk) then
            -- Default assignments
            data_ready <= '0';
            
            -- Process any received data
            if data_valid_in = '1' then
                response_received <= '1';
                output_data <= data_received;
            end if;
            
            case protocol_state is
                when IDLE =>
                    -- Wait for transaction start
                    carrier_enable <= '0';
                    mod_enable <= '0';
                    
                    if start_trans = '1' then
                        protocol_state <= FIELD_ON;
                        current_command <= command;
                        timeout_counter <= 0;
                    end if;
                
                when FIELD_ON =>
                    -- Turn on RF field and wait for stabilization
                    carrier_enable <= '1';
                    mod_enable <= '0';
                    
                    if timeout_counter < 1000 then -- Wait for field stabilization
                        timeout_counter <= timeout_counter + 1;
                    else
                        if field_detect = '1' then
                            protocol_state <= SEND_COMMAND;
                            timeout_counter <= 0;
                        end if;
                    end if;
                
                when SEND_COMMAND =>
                    -- Send command to tag
                    carrier_enable <= '1';
                    mod_enable <= '1';
                    tx_data <= current_command;
                    
                    if timeout_counter < 100 then -- Allow time for modulation
                        timeout_counter <= timeout_counter + 1;
                    else
                        protocol_state <= WAIT_RESPONSE;
                        timeout_counter <= 0;
                        response_received <= '0';
                    end if;
                
                when WAIT_RESPONSE =>
                    -- Wait for tag response
                    carrier_enable <= '1';
                    mod_enable <= '0';
                    
                    if response_received = '1' then
                        protocol_state <= PROCESS_RESPONSE;
                    elsif timeout_counter < 5000 then -- Timeout for response
                        timeout_counter <= timeout_counter + 1;
                    else
                        -- No response received
                        protocol_state <= FIELD_OFF;
                    end if;
                
                when PROCESS_RESPONSE =>
                    -- Process tag response
                    carrier_enable <= '1';
                    mod_enable <= '0';
                    data_ready <= '1';
                    
                    -- If sending data was requested
                    if command = CMD_SELECT then
                        -- Send data after processing response
                        protocol_state <= SEND_COMMAND;
                        current_command <= data_to_send;
                        timeout_counter <= 0;
                    else
                        protocol_state <= FIELD_OFF;
                    end if;
                
                when FIELD_OFF =>
                    -- Turn off RF field
                    carrier_enable <= '0';
                    mod_enable <= '0';
                    protocol_state <= IDLE;
                
                when others =>
                    protocol_state <= IDLE;
            end case;
        end if;
    end process;
    
    -- Output assignments
    data_out <= output_data;
    data_ready_out <= data_ready;
end Behavioral;
