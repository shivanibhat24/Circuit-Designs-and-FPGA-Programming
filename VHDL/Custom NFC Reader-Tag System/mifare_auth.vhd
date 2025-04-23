library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity mifare_auth is
    Port (
        clk         : in  STD_LOGIC;
        rst         : in  STD_LOGIC;
        start_auth  : in  STD_LOGIC;
        key_type    : in  STD_LOGIC;  -- '0' for Key A, '1' for Key B
        block_addr  : in  STD_LOGIC_VECTOR(7 downto 0);
        key_data    : in  STD_LOGIC_VECTOR(47 downto 0);
        uid         : in  STD_LOGIC_VECTOR(31 downto 0);
        -- Interface to protocol controller
        tx_data     : out STD_LOGIC_VECTOR(7 downto 0);
        rx_data     : in  STD_LOGIC_VECTOR(7 downto 0);
        data_valid  : in  STD_LOGIC;
        send_cmd    : out STD_LOGIC;
        -- Status outputs
        auth_done   : out STD_LOGIC;
        auth_success: out STD_LOGIC;
        error_code  : out STD_LOGIC_VECTOR(3 downto 0)
    );
end mifare_auth;

architecture Behavioral of mifare_auth is
    -- Authentication constants
    constant CMD_AUTH_A : STD_LOGIC_VECTOR(7 downto 0) := x"60"; -- Auth with Key A
    constant CMD_AUTH_B : STD_LOGIC_VECTOR(7 downto 0) := x"61"; -- Auth with Key B
    
    -- Authentication state machine
    type auth_state_type is (IDLE, SEND_AUTH_CMD, SEND_BLOCK, SEND_KEY_PART1, 
                           SEND_KEY_PART2, WAIT_RESPONSE, AUTH_SUCCESS, AUTH_FAILED);
    signal auth_state : auth_state_type := IDLE;
    
    -- Internal signals
    signal timeout_counter : integer range 0 to 10000 := 0;
    signal auth_cmd        : STD_LOGIC_VECTOR(7 downto 0) := CMD_AUTH_A;
    signal auth_status     : STD_LOGIC := '0';
    signal error_status    : STD_LOGIC_VECTOR(3 downto 0) := "0000";
    signal lfsr            : STD_LOGIC_VECTOR(31 downto 0) := (others => '0'); -- For random number generation
begin
    -- Authentication process
    process(clk, rst)
    begin
        if rst = '1' then
            auth_state <= IDLE;
            auth_status <= '0';
            error_status <= "0000";
            timeout_counter <= 0;
            send_cmd <= '0';
            tx_data <= (others => '0');
            lfsr <= x"12345678"; -- Initial LFSR seed
        elsif rising_edge(clk) then
            -- Default assignments
            send_cmd <= '0';
            
            -- LFSR for random number generation
            lfsr <= lfsr(30 downto 0) & (lfsr(31) xor lfsr(21) xor lfsr(1) xor lfsr(0));
            
            case auth_state is
                when IDLE =>
                    -- Wait for authentication start
                    auth_status <= '0';
                    error_status <= "0000";
                    
                    if start_auth = '1' then
                        -- Determine authentication command based on key type
                        if key_type = '0' then
                            auth_cmd <= CMD_AUTH_A;
                        else
                            auth_cmd <= CMD_AUTH_B;
                        end if;
                        
                        auth_state <= SEND_AUTH_CMD;
                    end if;
                
                when SEND_AUTH_CMD =>
                    -- Send authentication command
                    tx_data <= auth_cmd;
                    send_cmd <= '1';
                    auth_state <= SEND_BLOCK;
                    timeout_counter <= 0;
                
                when SEND_BLOCK =>
                    -- Send block address
                    tx_data <= block_addr;
                    send_cmd <= '1';
                    auth_state <= SEND_KEY_PART1;
                    timeout_counter <= 0;
                
                when SEND_KEY_PART1 =>
                    -- Send first part of key (bytes 0-3)
                    tx_data <= key_data(7 downto 0);
                    send_cmd <= '1';
                    auth_state <= SEND_KEY_PART2;
                    timeout_counter <= 0;
                
                when SEND_KEY_PART2 =>
                    -- Send second part of key (bytes 4-5)
                    tx_data <= key_data(15 downto 8);
                    send_cmd <= '1';
                    auth_state <= WAIT_RESPONSE;
                    timeout_counter <= 0;
                
                when WAIT_RESPONSE =>
                    -- Wait for tag response
                    if data_valid = '1' then
                        -- Check authentication response (simplified)
                        if rx_data = x"0A" then -- ACK
                            auth_state <= AUTH_SUCCESS;
                            auth_status <= '1';
                        else
                            auth_state <= AUTH_FAILED;
                            error_status <= "0001"; -- Authentication failed
                        end if;
                    elsif timeout_counter < 5000 then
                        timeout_counter <= timeout_counter + 1;
                    else
                        -- Timeout error
                        auth_state <= AUTH_FAILED;
                        error_status <= "0010"; -- Response timeout
                    end if;
                
                when AUTH_SUCCESS =>
                    -- Authentication successful
                    auth_status <= '1';
                    auth_state <= IDLE;
                
                when AUTH_FAILED =>
                    -- Authentication failed
                    auth_status <= '0';
                    auth_state <= IDLE;
                
                when others =>
                    auth_state <= IDLE;
            end case;
        end if;
    end process;
    
    -- Output assignments
    auth_done <= '1' when auth_state = AUTH_SUCCESS or auth_state = AUTH_FAILED else '0';
    auth_success <= auth_status;
    error_code <= error_status;
end Behavioral;
