-- =============================================================================
-- COMPREHENSIVE TESTBENCH
-- =============================================================================
-- File: tb_rsa_accelerator.vhd
-- Complete testbench for RSA accelerator verification

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.rsa_pkg.all;

entity tb_rsa_accelerator is
end tb_rsa_accelerator;

architecture behavioral of tb_rsa_accelerator is
    -- Test constants
    constant CLOCK_PERIOD : time := 10 ns;
    constant KEY_WIDTH : integer := 256;
    constant AXI_ADDR_WIDTH : integer := 32;
    constant AXI_DATA_WIDTH : integer := 32;
    
    -- Clock and reset
    signal clk : std_logic := '0';
    signal rst_n : std_logic := '0';
    
    -- AXI4-Lite signals
    signal s_axi_awaddr : std_logic_vector(AXI_ADDR_WIDTH-1 downto 0) := (others => '0');
    signal s_axi_awvalid : std_logic := '0';
    signal s_axi_awready : std_logic;
    signal s_axi_wdata : std_logic_vector(AXI_DATA_WIDTH-1 downto 0) := (others => '0');
    signal s_axi_wstrb : std_logic_vector((AXI_DATA_WIDTH/8)-1 downto 0) := (others => '1');
    signal s_axi_wvalid : std_logic := '0';
    signal s_axi_wready : std_logic;
    signal s_axi_bresp : std_logic_vector(1 downto 0);
    signal s_axi_bvalid : std_logic;
    signal s_axi_bready : std_logic := '1';
    signal s_axi_araddr : std_logic_vector(AXI_ADDR_WIDTH-1 downto 0) := (others => '0');
    signal s_axi_arvalid : std_logic := '0';
    signal s_axi_arready : std_logic;
    signal s_axi_rdata : std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
    signal s_axi_rresp : std_logic_vector(1 downto 0);
    signal s_axi_rvalid : std_logic;
    signal s_axi_rready : std_logic := '1';
    
    -- Other signals
    signal interrupt : std_logic;
    signal status_led : std_logic_vector(7 downto 0);
    
    -- Test data (small values for faster simulation)
    constant TEST_MESSAGE : std_logic_vector(KEY_WIDTH-1 downto 0) := 
        x"0000000000000000000000000000000000000000000000000000000000000042"; -- 66
    constant TEST_PUB_EXP : std_logic_vector(KEY_WIDTH-1 downto 0) := 
        x"0000000000000000000000000000000000000000000000000000000000000011"; -- 17
    constant TEST_PRIV_EXP : std_logic_vector(KEY_WIDTH-1 downto 0) := 
        x"0000000000000000000000000000000000000000000000000000000000000071"; -- 113
    constant TEST_MODULUS : std_logic_vector(KEY_WIDTH-1 downto 0) := 
        x"00000000000000000000000000000000000000000000000000000000000000C7"; -- 199
    
begin
    -- Clock generation
    clk <= not clk after CLOCK_PERIOD/2;
    
    -- DUT instantiation
    uut: entity work.rsa_accelerator_top
        generic map (
            KEY_WIDTH => KEY_WIDTH,
            AXI_ADDR_WIDTH => AXI_ADDR_WIDTH,
            AXI_DATA_WIDTH => AXI_DATA_WIDTH
        )
        port map (
            clk => clk,
            rst_n => rst_n,
            s_axi_awaddr => s_axi_awaddr,
            s_axi_awvalid => s_axi_awvalid,
            s_axi_awready => s_axi_awready,
            s_axi_wdata => s_axi_wdata,
            s_axi_wstrb => s_axi_wstrb,
            s_axi_wvalid => s_axi_wvalid,
            s_axi_wready => s_axi_wready,
            s_axi_bresp => s_axi_bresp,
            s_axi_bvalid => s_axi_bvalid,
            s_axi_bready => s_axi_bready,
            s_axi_araddr => s_axi_araddr,
            s_axi_arvalid => s_axi_arvalid,
            s_axi_arready => s_axi_arready,
            s_axi_rdata => s_axi_rdata,
            s_axi_rresp => s_axi_rresp,
            s_axi_rvalid => s_axi_rvalid,
            s_axi_rready => s_axi_rready,
            interrupt => interrupt,
            status_led => status_led
        );
    
    -- AXI Write Procedure
    procedure axi_write(
        addr : in std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);
        data : in std_logic_vector(AXI_DATA_WIDTH-1 downto 0)
    ) is
    begin
        wait until rising_edge(clk);
        s_axi_awaddr <= addr;
        s_axi_awvalid <= '1';
        s_axi_wdata <= data;
        s_axi_wvalid <= '1';
        
        wait until s_axi_awready = '1' and s_axi_wready = '1' and rising_edge(clk);
        s_axi_awvalid <= '0';
        s_axi_wvalid <= '0';
        
        wait until s_axi_bvalid = '1' and rising_edge(clk);
        wait until rising_edge(clk);
    end procedure;
    
    -- AXI Read Procedure
    procedure axi_read(
        addr : in std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);
        signal data : out std_logic_vector(AXI_DATA_WIDTH-1 downto 0)
    ) is
    begin
        wait until rising_edge(clk);
        s_axi_araddr <= addr;
        s_axi_arvalid <= '1';
        
        wait until s_axi_arready = '1' and rising_edge(clk);
        s_axi_arvalid <= '0';
        
        wait until s_axi_rvalid = '1' and rising_edge(clk);
        data <= s_axi_rdata;
        wait until rising_edge(clk);
    end procedure;
    
    -- Test process
    process
        variable read_data : std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
    begin
        -- Reset sequence
        rst_n <= '0';
        wait for 10 * CLOCK_PERIOD;
        rst_n <= '1';
        wait for 5 * CLOCK_PERIOD;
        
        report "Starting RSA Accelerator Test";
        
        -- Write test parameters
        report "Writing RSA parameters...";
        
        -- Write message (word by word)
        for i in 0 to (KEY_WIDTH/32)-1 loop
            axi_write(
                std_logic_vector(to_unsigned(16#10 + i*4, AXI_ADDR_WIDTH)),
                TEST_MESSAGE((i+1)*32-1 downto i*32)
            );
        end loop;
        
        -- Write public exponent
        for i in 0 to (KEY_WIDTH/32)-1 loop
            axi_write(
                std_logic_vector(to_unsigned(16#30 + i*4, AXI_ADDR_WIDTH)),
                TEST_PUB_EXP((i+1)*32-1 downto i*32)
            );
        end loop;
        
        -- Write private exponent
        for i in 0 to (KEY_WIDTH/32)-1 loop
            axi_write(
                std_logic_vector(to_unsigned(16#50 + i*4, AXI_ADDR_WIDTH)),
                TEST_PRIV_EXP((i+1)*32-1 downto i*32)
            );
        end loop;
        
        -- Write modulus
        for i in 0 to (KEY_WIDTH/32)-1 loop
            axi_write(
                std_logic_vector(to_unsigned(16#70 + i*4, AXI_ADDR_WIDTH)),
                TEST_MODULUS((i+1)*32-1 downto i*32)
            );
        end loop;
        
        -- Set operation to encrypt
        axi_write(x"00000008", x"00000000"); -- RSA_ENCRYPT
        
        -- Start operation
        report "Starting RSA encryption...";
        axi_write(x"00000000", x"00000001"); -- Set start bit
        
        -- Wait for completion
        loop
            axi_read(x"00000004", read_data);
            exit when read_data(1) = '1' or read_data(2) = '1'; -- done or error
            wait for 100 * CLOCK_PERIOD;
        end loop;
        
        if read_data(2) = '1' then
            report "RSA operation failed with error" severity error;
        else
            report "RSA encryption completed successfully";
            
            -- Read result
            report "Reading encryption result...";
            for i in 0 to (KEY_WIDTH/32)-1 loop
                axi_read(
                    std_logic_vector(to_unsigned(16#90 + i*4, AXI_ADDR_WIDTH)),
                    read_data
                );
                report "Result word " & integer'image(i) & ": " & 
                       to_hstring(read_data);
            end loop;
        end if;
        
        -- Test decryption
        wait for 10 * CLOCK_PERIOD;
        
        -- Set operation to decrypt
        axi_write(x"00000008", x"00000001"); -- RSA_DECRYPT
        
        -- Start operation
        report "Starting RSA decryption...";
        axi_write(x"00000000", x"00000001"); -- Set start bit
        
        -- Wait for completion
        loop
            axi_read(x"00000004", read_data);
            exit when read_data(1) = '1' or read_data(2) = '1'; -- done or error
            wait for 100 * CLOCK_PERIOD;
        end loop;
        
        if read_data(2) = '1' then
            report "RSA decryption failed with error" severity error;
        else
            report "RSA decryption completed successfully";
        end if;
        
        report "RSA Accelerator Test Completed";
        wait;
    end process;
    
    -- Monitor process
    process
    begin
        wait until interrupt = '1';
        report "Interrupt received - Operation completed";
        wait until interrupt = '0';
    end process;

end behavioral;
