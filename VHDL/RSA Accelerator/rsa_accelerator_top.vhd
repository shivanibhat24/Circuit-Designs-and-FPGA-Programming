-- =============================================================================
-- TOP-LEVEL RSA ACCELERATOR
-- =============================================================================
-- File: rsa_accelerator_top.vhd
-- Complete RSA accelerator with memory interface and control logic

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.rsa_pkg.all;

entity rsa_accelerator_top is
    generic (
        KEY_WIDTH     : integer := RSA_KEY_WIDTH;
        ADDR_WIDTH    : integer := ADDR_WIDTH;
        AXI_ADDR_WIDTH: integer := 32;
        AXI_DATA_WIDTH: integer := 32
    );
    port (
        -- Clock and reset
        clk           : in  std_logic;
        rst_n         : in  std_logic;
        
        -- AXI4-Lite interface for configuration
        s_axi_awaddr  : in  std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);
        s_axi_awvalid : in  std_logic;
        s_axi_awready : out std_logic;
        s_axi_wdata   : in  std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
        s_axi_wstrb   : in  std_logic_vector((AXI_DATA_WIDTH/8)-1 downto 0);
        s_axi_wvalid  : in  std_logic;
        s_axi_wready  : out std_logic;
        s_axi_bresp   : out std_logic_vector(1 downto 0);
        s_axi_bvalid  : out std_logic;
        s_axi_bready  : in  std_logic;
        s_axi_araddr  : in  std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);
        s_axi_arvalid : in  std_logic;
        s_axi_arready : out std_logic;
        s_axi_rdata   : out std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
        s_axi_rresp   : out std_logic_vector(1 downto 0);
        s_axi_rvalid  : out std_logic;
        s_axi_rready  : in  std_logic;
        
        -- Interrupt output
        interrupt     : out std_logic;
        
        -- Status LEDs (optional)
        status_led    : out std_logic_vector(7 downto 0)
    );
end rsa_accelerator_top;

architecture structural of rsa_accelerator_top is
    -- Internal reset
    signal rst : std_logic;
    
    -- Register map addresses
    constant REG_CONTROL    : std_logic_vector(7 downto 0) := x"00";
    constant REG_STATUS     : std_logic_vector(7 downto 0) := x"04";
    constant REG_OPERATION  : std_logic_vector(7 downto 0) := x"08";
    constant REG_MESSAGE    : std_logic_vector(7 downto 0) := x"10"; -- Base address
    constant REG_PUB_EXP    : std_logic_vector(7 downto 0) := x"30"; -- Base address
    constant REG_PRIV_EXP   : std_logic_vector(7 downto 0) := x"50"; -- Base address
    constant REG_MODULUS    : std_logic_vector(7 downto 0) := x"70"; -- Base address
    constant REG_RESULT     : std_logic_vector(7 downto 0) := x"90"; -- Base address
    
    -- Control and status registers
    signal control_reg : std_logic_vector(31 downto 0);
    signal status_reg  : std_logic_vector(31 downto 0);
    signal op_reg      : std_logic_vector(31 downto 0);
    
    -- RSA parameters (stored in internal memory)
    signal message_mem    : std_logic_vector(KEY_WIDTH-1 downto 0);
    signal pub_exp_mem    : std_logic_vector(KEY_WIDTH-1 downto 0);
    signal priv_exp_mem   : std_logic_vector(KEY_WIDTH-1 downto 0);
    signal modulus_mem    : std_logic_vector(KEY_WIDTH-1 downto 0);
    signal result_mem     : std_logic_vector(KEY_WIDTH-1 downto 0);
    
    -- RSA core interface
    signal rsa_start      : std_logic;
    signal rsa_operation  : rsa_op_type;
    signal rsa_done       : std_logic;
    signal rsa_busy       : std_logic;
    signal rsa_error      : std_logic;
    
    -- AXI interface signals
    signal axi_awready    : std_logic;
    signal axi_wready     : std_logic;
    signal axi_bvalid     : std_logic;
    signal axi_arready    : std_logic;
    signal axi_rvalid     : std_logic;
    signal axi_rdata      : std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
    
    -- Internal control signals
    signal start_pulse    : std_logic;
    signal prev_start     : std_logic;
    
begin
    -- Reset logic
    rst <= not rst_n;
    
    -- RSA core instantiation
    rsa_core_inst: rsa_core
        generic map (
            KEY_WIDTH => KEY_WIDTH
        )
        port map (
            clk => clk,
            rst => rst,
            start => rsa_start,
            operation => rsa_operation,
            message => message_mem,
            public_exp => pub_exp_mem,
            private_exp => priv_exp_mem,
            modulus => modulus_mem,
            result => result_mem,
            done => rsa_done,
            busy => rsa_busy,
            error => rsa_error
        );
    
    -- AXI4-Lite interface assignments
    s_axi_awready <= axi_awready;
    s_axi_wready <= axi_wready;
    s_axi_bvalid <= axi_bvalid;
    s_axi_bresp <= "00"; -- OKAY response
    s_axi_arready <= axi_arready;
    s_axi_rvalid <= axi_rvalid;
    s_axi_rdata <= axi_rdata;
    s_axi_rresp <= "00"; -- OKAY response
    
    -- Operation type mapping
    process(op_reg)
    begin
        case op_reg(1 downto 0) is
            when "00" => rsa_operation <= RSA_ENCRYPT;
            when "01" => rsa_operation <= RSA_DECRYPT;
            when "10" => rsa_operation <= RSA_SIGN;
            when "11" => rsa_operation <= RSA_VERIFY;
            when others => rsa_operation <= RSA_ENCRYPT;
        end case;
    end process;
    
    -- Start pulse generation
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                prev_start <= '0';
                start_pulse <= '0';
            else
                prev_start <= control_reg(0);
                start_pulse <= control_reg(0) and not prev_start;
            end if;
        end if;
    end process;
    
    rsa_start <= start_pulse;
    
    -- Status register update
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                status_reg <= (others => '0');
            else
                status_reg(0) <= rsa_busy;
                status_reg(1) <= rsa_done;
                status_reg(2) <= rsa_error;
                status_reg(31 downto 3) <= (others => '0');
            end if;
        end if;
    end process;
    
    -- Interrupt generation
    interrupt <= rsa_done or rsa_error;
    
    -- Status LEDs
    status_led(0) <= rsa_busy;
    status_led(1) <= rsa_done;
    status_led(2) <= rsa_error;
    status_led(3) <= control_reg(0);
    status_led(7 downto 4) <= op_reg(3 downto 0);
    
    -- AXI4-Lite Write Channel
    process(clk)
        variable write_addr : integer;
        variable word_index : integer;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                axi_awready <= '0';
                axi_wready <= '0';
                axi_bvalid <= '0';
                control_reg <= (others => '0');
                op_reg <= (others => '0');
                message_mem <= (others => '0');
                pub_exp_mem <= (others => '0');
                priv_exp_mem <= (others => '0');
                modulus_mem <= (others => '0');
            else
                -- Write address ready
                if s_axi_awvalid = '1' and axi_awready = '0' then
                    axi_awready <= '1';
                else
                    axi_awready <= '0';
                end if;
                
                -- Write data ready
                if s_axi_wvalid = '1' and axi_wready = '0' then
                    axi_wready <= '1';
                else
                    axi_wready <= '0';
                end if;
                
                -- Write response
                if s_axi_awvalid = '1' and s_axi_wvalid = '1' and axi_bvalid = '0' then
                    axi_bvalid <= '1';
                    
                    -- Decode write address and perform write
                    write_addr := to_integer(unsigned(s_axi_awaddr(7 downto 0)));
                    
                    case write_addr is
                        when to_integer(unsigned(REG_CONTROL)) =>
                            if s_axi_wstrb(0) = '1' then control_reg(7 downto 0) <= s_axi_wdata(7 downto 0); end if;
                            if s_axi_wstrb(1) = '1' then control_reg(15 downto 8) <= s_axi_wdata(15 downto 8); end if;
                            if s_axi_wstrb(2) = '1' then control_reg(23 downto 16) <= s_axi_wdata(23 downto 16); end if;
                            if s_axi_wstrb(3) = '1' then control_reg(31 downto 24) <= s_axi_wdata(31 downto 24); end if;
                        
                        when to_integer(unsigned(REG_OPERATION)) =>
                            if s_axi_wstrb(0) = '1' then op_reg(7 downto 0) <= s_axi_wdata(7 downto 0); end if;
                            if s_axi_wstrb(1) = '1' then op_reg(15 downto 8) <= s_axi_wdata(15 downto 8); end if;
                            if s_axi_wstrb(2) = '1' then op_reg(23 downto 16) <= s_axi_wdata(23 downto 16); end if;
                            if s_axi_wstrb(3) = '1' then op_reg(31 downto 24) <= s_axi_wdata(31 downto 24); end if;
                        
                        when others =>
                            -- Handle multi-word register writes
                            if write_addr >= to_integer(unsigned(REG_MESSAGE)) and 
                               write_addr < to_integer(unsigned(REG_PUB_EXP)) then
                                word_index := (write_addr - to_integer(unsigned(REG_MESSAGE))) / 4;
                                if word_index < KEY_WIDTH/32 then
                                    message_mem((word_index+1)*32-1 downto word_index*32) <= s_axi_wdata;
                                end if;
                            elsif write_addr >= to_integer(unsigned(REG_PUB_EXP)) and 
                                  write_addr < to_integer(unsigned(REG_PRIV_EXP)) then
                                word_index := (write_addr - to_integer(unsigned(REG_PUB_EXP))) / 4;
                                if word_index < KEY_WIDTH/32 then
                                    pub_exp_mem((word_index+1)*32-1 downto word_index*32) <= s_axi_wdata;
                                end if;
                            elsif write_addr >= to_integer(unsigned(REG_PRIV_EXP)) and 
                                  write_addr < to_integer(unsigned(REG_MODULUS)) then
                                word_index := (write_addr - to_integer(unsigned(REG_PRIV_EXP))) / 4;
                                if word_index < KEY_WIDTH/32 then
                                    priv_exp_mem((word_index+1)*32-1 downto word_index*32) <= s_axi_wdata;
                                end if;
                            elsif write_addr >= to_integer(unsigned(REG_MODULUS)) and 
                                  write_addr < to_integer(unsigned(REG_RESULT)) then
                                word_index := (write_addr - to_integer(unsigned(REG_MODULUS))) / 4;
                                if word_index < KEY_WIDTH/32 then
                                    modulus_mem((word_index+1)*32-1 downto word_index*32) <= s_axi_wdata;
                                end if;
                            end if;
                    end case;
                elsif s_axi_bready = '1' and axi_bvalid = '1' then
                    axi_bvalid <= '0';
                end if;
            end if;
        end if;
    end process;
    
    -- AXI4-Lite Read Channel
    process(clk)
        variable read_addr : integer;
        variable word_index : integer;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                axi_arready <= '0';
                axi_rvalid <= '0';
                axi_rdata <= (others => '0');
            else
                -- Read address ready
                if s_axi_arvalid = '1' and axi_arready = '0' then
                    axi_arready <= '1';
                    axi_rvalid <= '1';
                    
                    -- Decode read address
                    read_addr := to_integer(unsigned(s_axi_araddr(7 downto 0)));
                    
                    case read_addr is
                        when to_integer(unsigned(REG_CONTROL)) =>
                            axi_rdata <= control_reg;
                        
                        when to_integer(unsigned(REG_STATUS)) =>
                            axi_rdata <= status_reg;
                        
                        when to_integer(unsigned(REG_OPERATION)) =>
                            axi_rdata <= op_reg;
                        
                        when others =>
                            -- Handle multi-word register reads
                            if read_addr >= to_integer(unsigned(REG_MESSAGE)) and 
                               read_addr < to_integer(unsigned(REG_PUB_EXP)) then
                                word_index := (read_addr - to_integer(unsigned(REG_MESSAGE))) / 4;
                                if word_index < KEY_WIDTH/32 then
                                    axi_rdata <= message_mem((word_index+1)*32-1 downto word_index*32);
                                else
                                    axi_rdata <= (others => '0');
                                end if;
                            elsif read_addr >= to_integer(unsigned(REG_PUB_EXP)) and 
                                  read_addr < to_integer(unsigned(REG_PRIV_EXP)) then
                                word_index := (read_addr - to_integer(unsigned(REG_PUB_EXP))) / 4;
                                if word_index < KEY_WIDTH/32 then
                                    axi_rdata <= pub_exp_mem((word_index+1)*32-1 downto word_index*32);
                                else
                                    axi_rdata <= (others => '0');
                                end if;
                            elsif read_addr >= to_integer(unsigned(REG_PRIV_EXP)) and 
                                  read_addr < to_integer(unsigned(REG_MODULUS)) then
                                word_index := (read_addr - to_integer(unsigned(REG_PRIV_EXP))) / 4;
                                if word_index < KEY_WIDTH/32 then
                                    axi_rdata <= priv_exp_mem((word_index+1)*32-1 downto word_index*32);
                                else
                                    axi_rdata <= (others => '0');
                                end if;
                            elsif read_addr >= to_integer(unsigned(REG_MODULUS)) and 
                                  read_addr < to_integer(unsigned(REG_RESULT)) then
                                word_index := (read_addr - to_integer(unsigned(REG_MODULUS))) / 4;
                                if word_index < KEY_WIDTH/32 then
                                    axi_rdata <= modulus_mem((word_index+1)*32-1 downto word_index*32);
                                else
                                    axi_rdata <= (others => '0');
                                end if;
                            elsif read_addr >= to_integer(unsigned(REG_RESULT)) then
                                word_index := (read_addr - to_integer(unsigned(REG_RESULT))) / 4;
                                if word_index < KEY_WIDTH/32 then
                                    axi_rdata <= result_mem((word_index+1)*32-1 downto word_index*32);
                                else
                                    axi_rdata <= (others => '0');
                                end if;
                            else
                                axi_rdata <= (others => '0');
                            end if;
                    end case;
                else
                    axi_arready <= '0';
                end if;
                
                if s_axi_rready = '1' and axi_rvalid = '1' then
                    axi_rvalid <= '0';
                end if;
            end if;
        end if;
    end process;

end structural;
