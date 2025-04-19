library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity DRAM_Controller is
    Port (
        -- System signals
        clk         : in  STD_LOGIC;                      -- System clock
        rst_n       : in  STD_LOGIC;                      -- Active low reset
        
        -- CPU interface
        addr        : in  STD_LOGIC_VECTOR(23 downto 0);  -- Address from CPU (24-bit address space)
        data_in     : in  STD_LOGIC_VECTOR(15 downto 0);  -- Data from CPU
        data_out    : out STD_LOGIC_VECTOR(15 downto 0);  -- Data to CPU
        rd_req      : in  STD_LOGIC;                      -- Read request
        wr_req      : in  STD_LOGIC;                      -- Write request
        busy        : out STD_LOGIC;                      -- Controller busy signal
        data_valid  : out STD_LOGIC;                      -- Data valid signal
        
        -- DRAM interface
        dram_addr   : out STD_LOGIC_VECTOR(12 downto 0);  -- DRAM address bus (row/column)
        dram_bank   : out STD_LOGIC_VECTOR(1 downto 0);   -- DRAM bank select
        dram_data   : inout STD_LOGIC_VECTOR(15 downto 0); -- DRAM data bus
        dram_clk    : out STD_LOGIC;                      -- DRAM clock
        dram_cke    : out STD_LOGIC;                      -- Clock enable
        dram_cs_n   : out STD_LOGIC;                      -- Chip select
        dram_ras_n  : out STD_LOGIC;                      -- Row address strobe
        dram_cas_n  : out STD_LOGIC;                      -- Column address strobe
        dram_we_n   : out STD_LOGIC;                      -- Write enable
        dram_dqm    : out STD_LOGIC_VECTOR(1 downto 0)    -- Data mask
    );
end DRAM_Controller;

architecture Behavioral of DRAM_Controller is
    -- DRAM command encoding (CS_N, RAS_N, CAS_N, WE_N)
    constant CMD_NOP      : STD_LOGIC_VECTOR(3 downto 0) := "0111";
    constant CMD_ACTIVE   : STD_LOGIC_VECTOR(3 downto 0) := "0011";
    constant CMD_READ     : STD_LOGIC_VECTOR(3 downto 0) := "0101";
    constant CMD_WRITE    : STD_LOGIC_VECTOR(3 downto 0) := "0100";
    constant CMD_PRECHARGE: STD_LOGIC_VECTOR(3 downto 0) := "0010";
    constant CMD_REFRESH  : STD_LOGIC_VECTOR(3 downto 0) := "0001";
    constant CMD_LOAD_MODE: STD_LOGIC_VECTOR(3 downto 0) := "0000";
    
    -- Timing parameters (in clock cycles)
    constant T_RC   : integer := 8;  -- Row cycle time
    constant T_RAS  : integer := 5;  -- Row active time
    constant T_RCD  : integer := 2;  -- RAS to CAS delay
    constant T_RP   : integer := 2;  -- Precharge time
    constant T_REF  : integer := 64; -- Refresh period (simplified)
    
    -- Mode register settings
    constant MODE_REG : STD_LOGIC_VECTOR(12 downto 0) := "0000000100001"; -- CAS Latency = 2, Burst Length = 1
    
    -- DRAM controller states
    type state_type is (
        INIT, IDLE, ROW_ACTIVE, READ_CMD, READ_DATA, 
        WRITE_CMD, WRITE_DATA, PRECHARGE, AUTO_REFRESH
    );
    
    signal state, next_state : state_type;
    
    -- Internal registers
    signal row_addr    : STD_LOGIC_VECTOR(12 downto 0);
    signal col_addr    : STD_LOGIC_VECTOR(9 downto 0);
    signal bank        : STD_LOGIC_VECTOR(1 downto 0);
    signal active_row  : STD_LOGIC_VECTOR(12 downto 0);
    signal active_bank : STD_LOGIC_VECTOR(1 downto 0);
    signal data_reg    : STD_LOGIC_VECTOR(15 downto 0);
    
    -- Control signals
    signal cmd         : STD_LOGIC_VECTOR(3 downto 0);
    signal row_active  : STD_LOGIC := '0';
    signal data_drive  : STD_LOGIC := '0';
    
    -- Counters
    signal init_cnt    : integer range 0 to 20000 := 0;
    signal timer       : integer range 0 to 15 := 0;
    signal ref_cnt     : integer range 0 to T_REF := 0;
    
begin
    -- Address mapping
    bank      <= addr(21 downto 20);
    row_addr  <= addr(19 downto 7);
    col_addr  <= addr(6 downto 0) & "000";  -- Column address with bank interleaving
    
    -- Command signal assignments
    dram_cs_n  <= cmd(3);
    dram_ras_n <= cmd(2);
    dram_cas_n <= cmd(1);
    dram_we_n  <= cmd(0);
    
    -- Data bus tristate control
    dram_data <= data_in when data_drive = '1' else (others => 'Z');
    
    -- Clock and clock enable
    dram_clk <= clk;
    dram_cke <= '1';  -- Always enabled in this design
    
    -- DRAM controller FSM
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            state <= INIT;
            init_cnt <= 0;
            timer <= 0;
            ref_cnt <= 0;
            busy <= '1';
            data_valid <= '0';
            data_drive <= '0';
            row_active <= '0';
            cmd <= CMD_NOP;
            dram_dqm <= "11";  -- Mask outputs during initialization
            dram_addr <= (others => '0');
            dram_bank <= "00";
            active_row <= (others => '0');
            active_bank <= "00";
        elsif rising_edge(clk) then
            -- Default assignments
            busy <= '1';  -- Default to busy
            data_valid <= '0';
            cmd <= CMD_NOP;
            
            -- Counter for auto-refresh
            if ref_cnt < T_REF then
                ref_cnt <= ref_cnt + 1;
            end if;
            
            -- Timer for command sequencing
            if timer > 0 then
                timer <= timer - 1;
            end if;
            
            -- State machine
            case state is
                when INIT =>
                    -- Initialization sequence
                    if init_cnt < 20000 then  -- Wait for 200us (assuming 100MHz clock)
                        init_cnt <= init_cnt + 1;
                        cmd <= CMD_NOP;
                    elsif init_cnt = 20000 then
                        cmd <= CMD_PRECHARGE;
                        dram_addr <= (others => '1');  -- Precharge all banks
                        init_cnt <= init_cnt + 1;
                        timer <= T_RP;
                    elsif timer = 0 and init_cnt = 20001 then
                        cmd <= CMD_REFRESH;
                        init_cnt <= init_cnt + 1;
                        timer <= T_RC;
                    elsif timer = 0 and init_cnt = 20002 then
                        cmd <= CMD_REFRESH;
                        init_cnt <= init_cnt + 1;
                        timer <= T_RC;
                    elsif timer = 0 and init_cnt = 20003 then
                        cmd <= CMD_LOAD_MODE;
                        dram_addr <= MODE_REG;
                        dram_bank <= "00";
                        init_cnt <= init_cnt + 1;
                        timer <= 2;  -- Wait 2 cycles after mode register set
                    elsif timer = 0 and init_cnt > 20003 then
                        state <= IDLE;
                        dram_dqm <= "00";  -- Enable data output
                        busy <= '0';  -- Controller is now ready
                    end if;
                    
                when IDLE =>
                    busy <= '0';
                    
                    -- Check if refresh is needed
                    if ref_cnt = T_REF then
                        if row_active = '1' then
                            state <= PRECHARGE;
                            cmd <= CMD_PRECHARGE;
                            dram_addr <= (others => '1');  -- Precharge all banks
                            timer <= T_RP;
                        else
                            state <= AUTO_REFRESH;
                            cmd <= CMD_REFRESH;
                            ref_cnt <= 0;
                            timer <= T_RC;
                        end if;
                    -- Check for read/write requests
                    elsif rd_req = '1' or wr_req = '1' then
                        if row_active = '1' and (active_row /= row_addr or active_bank /= bank) then
                            -- Different row/bank, need to precharge first
                            state <= PRECHARGE;
                            cmd <= CMD_PRECHARGE;
                            dram_addr <= (others => '1');  -- Precharge all banks
                            timer <= T_RP;
                        elsif row_active = '0' then
                            -- No row active, activate the requested row
                            state <= ROW_ACTIVE;
                            cmd <= CMD_ACTIVE;
                            dram_addr <= row_addr;
                            dram_bank <= bank;
                            active_row <= row_addr;
                            active_bank <= bank;
                            timer <= T_RCD;
                            row_active <= '1';
                        else
                            -- Row already active and matches request
                            if rd_req = '1' then
                                state <= READ_CMD;
                                cmd <= CMD_READ;
                                dram_addr <= "000" & col_addr;
                                dram_bank <= bank;
                                timer <= 2;  -- CAS Latency = 2
                            else  -- wr_req = '1'
                                state <= WRITE_CMD;
                                cmd <= CMD_WRITE;
                                dram_addr <= "000" & col_addr;
                                dram_bank <= bank;
                                data_drive <= '1';
                                timer <= 1;
                            end if;
                        end if;
                    end if;
                    
                when ROW_ACTIVE =>
                    if timer = 0 then
                        if rd_req = '1' then
                            state <= READ_CMD;
                            cmd <= CMD_READ;
                            dram_addr <= "000" & col_addr;
                            dram_bank <= bank;
                            timer <= 2;  -- CAS Latency = 2
                        else  -- wr_req = '1'
                            state <= WRITE_CMD;
                            cmd <= CMD_WRITE;
                            dram_addr <= "000" & col_addr;
                            dram_bank <= bank;
                            data_drive <= '1';
                            timer <= 1;
                        end if;
                    end if;
                    
                when READ_CMD =>
                    if timer = 0 then
                        state <= READ_DATA;
                    end if;
                    
                when READ_DATA =>
                    data_reg <= dram_data;
                    data_out <= dram_data;
                    data_valid <= '1';
                    state <= IDLE;
                    
                when WRITE_CMD =>
                    if timer = 0 then
                        state <= WRITE_DATA;
                    end if;
                    
                when WRITE_DATA =>
                    data_drive <= '0';
                    state <= IDLE;
                    
                when PRECHARGE =>
                    if timer = 0 then
                        row_active <= '0';
                        if ref_cnt = T_REF then
                            state <= AUTO_REFRESH;
                            cmd <= CMD_REFRESH;
                            ref_cnt <= 0;
                            timer <= T_RC;
                        else
                            state <= ROW_ACTIVE;
                            cmd <= CMD_ACTIVE;
                            dram_addr <= row_addr;
                            dram_bank <= bank;
                            active_row <= row_addr;
                            active_bank <= bank;
                            timer <= T_RCD;
                            row_active <= '1';
                        end if;
                    end if;
                    
                when AUTO_REFRESH =>
                    if timer = 0 then
                        state <= IDLE;
                    end if;
            end case;
        end if;
    end process;

end Behavioral;
