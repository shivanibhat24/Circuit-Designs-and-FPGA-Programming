-- SD Card Controller Component
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sd_controller is
    Port (
        clk          : in  STD_LOGIC;
        reset_n      : in  STD_LOGIC;
        sd_clk       : out STD_LOGIC;
        sd_cmd       : inout STD_LOGIC;
        sd_dat       : inout STD_LOGIC_VECTOR(3 downto 0);
        
        -- Write Interface
        write_en     : in  STD_LOGIC;
        write_data   : in  STD_LOGIC_VECTOR(31 downto 0);
        write_addr   : in  STD_LOGIC_VECTOR(31 downto 0);
        write_ready  : out STD_LOGIC;
        
        -- Read Interface
        read_en      : in  STD_LOGIC;
        read_addr    : in  STD_LOGIC_VECTOR(31 downto 0);
        read_data    : out STD_LOGIC_VECTOR(31 downto 0);
        read_valid   : out STD_LOGIC;
        
        -- Status
        card_ready   : out STD_LOGIC;
        error        : out STD_LOGIC
    );
end sd_controller;

architecture Behavioral of sd_controller is
    
    type sd_state_type is (
        IDLE, INIT, CMD0, CMD8, ACMD41, CMD58, CMD16,
        READY, WRITE_CMD, WRITE_DATA, WRITE_WAIT,
        READ_CMD, READ_DATA, READ_WAIT, ERROR_ST
    );
    
    signal sd_state : sd_state_type;
    signal clk_div : unsigned(7 downto 0);
    signal sd_clk_int : STD_LOGIC;
    signal cmd_counter : unsigned(5 downto 0);
    signal data_counter : unsigned(8 downto 0);
    signal response_reg : STD_LOGIC_VECTOR(47 downto 0);
    signal write_buffer : STD_LOGIC_VECTOR(511 downto 0);
    signal read_buffer : STD_LOGIC_VECTOR(511 downto 0);
    signal timeout_counter : unsigned(15 downto 0);
    signal init_done : STD_LOGIC;
    signal crc7_reg : STD_LOGIC_VECTOR(6 downto 0);
    
    -- CRC7 calculation function
    function calc_crc7(data_in: STD_LOGIC_VECTOR; prev_crc: STD_LOGIC_VECTOR(6 downto 0)) 
        return STD_LOGIC_VECTOR is
        variable crc : STD_LOGIC_VECTOR(6 downto 0);
    begin
        crc := prev_crc;
        for i in data_in'high downto data_in'low loop
            if crc(6) /= data_in(i) then
                crc := (crc(5 downto 0) & '0') xor "0001001";
            else
                crc := crc(5 downto 0) & '0';
            end if;
        end loop;
        return crc;
    end function;

begin

    -- Generate SD clock (400kHz for init, 25MHz for data)
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            clk_div <= (others => '0');
            sd_clk_int <= '0';
        elsif rising_edge(clk) then
            if init_done = '0' then
                -- Slow clock for initialization (400kHz from 25MHz)
                if clk_div = 62 then
                    clk_div <= (others => '0');
                    sd_clk_int <= not sd_clk_int;
                else
                    clk_div <= clk_div + 1;
                end if;
            else
                -- Fast clock for data transfer (12.5MHz from 25MHz)
                if clk_div(0) = '1' then
                    sd_clk_int <= not sd_clk_int;
                end if;
                clk_div <= clk_div + 1;
            end if;
        end if;
    end process;
    
    sd_clk <= sd_clk_int;
    
    -- Main SD controller state machine
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            sd_state <= IDLE;
            card_ready <= '0';
            error <= '0';
            write_ready <= '0';
            read_valid <= '0';
            init_done <= '0';
            cmd_counter <= (others => '0');
            data_counter <= (others => '0');
            timeout_counter <= (others => '0');
            sd_cmd <= 'Z';
            sd_dat <= (others => 'Z');
            
        elsif rising_edge(clk) then
            case sd_state is
                when IDLE =>
                    card_ready <= '0';
                    error <= '0';
                    write_ready <= '0';
                    read_valid <= '0';
                    timeout_counter <= timeout_counter + 1;
                    
                    if timeout_counter = 1000 then -- Wait for card stabilization
                        sd_state <= INIT;
                        timeout_counter <= (others => '0');
                    end if;
                
                when INIT =>
                    -- Send 74+ clock cycles with CMD high
                    sd_cmd <= '1';
                    cmd_counter <= cmd_counter + 1;
                    if cmd_counter = 63 then
                        sd_state <= CMD0;
                        cmd_counter <= (others => '0');
                    end if;
                
                when CMD0 =>
                    -- Send CMD0 (GO_IDLE_STATE)
                    if cmd_counter = 0 then
                        sd_cmd <= '0'; -- Start bit
                    elsif cmd_counter = 1 then
                        sd_cmd <= '1'; -- Transmission bit
                    elsif cmd_counter >= 2 and cmd_counter <= 7 then
                        sd_cmd <= '0'; -- Command index (000000)
                    elsif cmd_counter >= 8 and cmd_counter <= 39 then
                        sd_cmd <= '0'; -- Argument (all zeros)
                    elsif cmd_counter >= 40 and cmd_counter <= 46 then
                        sd_cmd <= '1' when cmd_counter = 40 else '0'; -- CRC7
                    elsif cmd_counter = 47 then
                        sd_cmd <= '1'; -- End bit
                        sd_cmd <= 'Z'; -- Release for response
                    end if;
                    
                    cmd_counter <= cmd_counter + 1;
                    if cmd_counter = 55 then
                        sd_state <= CMD8;
                        cmd_counter <= (others => '0');
                    end if;
                
                when CMD8 =>
                    -- Send CMD8 (SEND_IF_COND) and wait for response
                    -- Simplified - assume SDHC card
                    timeout_counter <= timeout_counter + 1;
                    if timeout_counter = 1000 then
                        sd_state <= ACMD41;
                        timeout_counter <= (others => '0');
                    end if;
                
                when ACMD41 =>
                    -- Send ACMD41 (SD_SEND_OP_COND)
                    timeout_counter <= timeout_counter + 1;
                    if timeout_counter = 10000 then
                        sd_state <= READY;
                        init_done <= '1';
                        card_ready <= '1';
                        timeout_counter <= (others => '0');
                    end if;
                
                when READY =>
                    write_ready <= not write_en; -- Ready when not writing
                    
                    if write_en = '1' then
                        sd_state <= WRITE_CMD;
                        write_buffer(31 downto 0) <= write_data;
                        cmd_counter <= (others => '0');
                    elsif read_en = '1' then
                        sd_state <= READ_CMD;
                        cmd_counter <= (others => '0');
                    end if;
                
                when WRITE_CMD =>
                    -- Send CMD24 (WRITE_SINGLE_BLOCK)
                    cmd_counter <= cmd_counter + 1;
                    if cmd_counter = 55 then
                        sd_state <= WRITE_DATA;
                        data_counter <= (others => '0');
                    end if;
                
                when WRITE_DATA =>
                    -- Send data block (512 bytes + CRC)
                    data_counter <= data_counter + 1;
                    if data_counter = 511 then
                        sd_state <= WRITE_WAIT;
                        timeout_counter <= (others => '0');
                    end if;
                
                when WRITE_WAIT =>
                    -- Wait for write completion
                    timeout_counter <= timeout_counter + 1;
                    if timeout_counter = 1000 then
                        sd_state <= READY;
                        write_ready <= '1';
                    end if;
                
                when READ_CMD =>
                    -- Send CMD17 (READ_SINGLE_BLOCK)
                    cmd_counter <= cmd_counter + 1;
                    if cmd_counter = 55 then
                        sd_state <= READ_DATA;
                        data_counter <= (others => '0');
                    end if;
                
                when READ_DATA =>
                    -- Receive data block
                    data_counter <= data_counter + 1;
                    if data_counter = 511 then
                        read_data <= read_buffer(31 downto 0);
                        read_valid <= '1';
                        sd_state <= READY;
                    end if;
                
                when READ_WAIT =>
                    sd_state <= READY;
                
                when ERROR_ST =>
                    error <= '1';
                    if timeout_counter = 10000 then
                        sd_state <= IDLE;
                        timeout_counter <= (others => '0');
                    else
                        timeout_counter <= timeout_counter + 1;
                    end if;
                
                when others =>
                    sd_state <= ERROR_ST;
            end case;
        end if;
    end process;

end Behavioral;
