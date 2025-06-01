-- =============================================================================
-- SYSTOLIC ARRAY
-- =============================================================================
-- File: systolic_array.vhd
-- Array of Montgomery PEs for parallel computation

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.rsa_pkg.all;

entity systolic_array is
    generic (
        DATA_WIDTH : integer := PE_DATA_WIDTH;
        ARRAY_SIZE : integer := SYSTOLIC_SIZE
    );
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        start     : in  std_logic;
        x_data    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        y_data    : in  std_logic_vector(DATA_WIDTH*ARRAY_SIZE-1 downto 0);
        m_data    : in  std_logic_vector(DATA_WIDTH*ARRAY_SIZE-1 downto 0);
        result    : out std_logic_vector(DATA_WIDTH*ARRAY_SIZE-1 downto 0);
        valid     : out std_logic;
        busy      : out std_logic
    );
end systolic_array;

architecture structural of systolic_array is
    type x_chain_type is array (0 to ARRAY_SIZE) of std_logic_vector(DATA_WIDTH-1 downto 0);
    type c_chain_type is array (0 to ARRAY_SIZE) of std_logic_vector(DATA_WIDTH downto 0);
    type valid_chain_type is array (0 to ARRAY_SIZE-1) of std_logic;
    
    signal x_chain : x_chain_type;
    signal c_chain : c_chain_type;
    signal pe_valid : valid_chain_type;
    signal enable_pe : std_logic;
    signal counter : integer range 0 to DATA_WIDTH+ARRAY_SIZE+1;
    signal busy_reg : std_logic;
    signal valid_reg : std_logic;
    
begin
    -- Control FSM
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                counter <= 0;
                enable_pe <= '0';
                valid_reg <= '0';
                busy_reg <= '0';
            elsif start = '1' and busy_reg = '0' then
                counter <= DATA_WIDTH + ARRAY_SIZE;
                enable_pe <= '1';
                valid_reg <= '0';
                busy_reg <= '1';
            elsif counter > 0 then
                counter <= counter - 1;
                if counter = 1 then
                    valid_reg <= '1';
                    enable_pe <= '0';
                    busy_reg <= '0';
                end if;
            else
                valid_reg <= '0';
            end if;
        end if;
    end process;
    
    -- Initialize data chains
    x_chain(0) <= x_data;
    c_chain(0) <= (others => '0');
    
    -- Generate PE array
    gen_pe_array: for i in 0 to ARRAY_SIZE-1 generate
        pe_inst: montgomery_pe
            generic map (
                DATA_WIDTH => DATA_WIDTH
            )
            port map (
                clk => clk,
                rst => rst,
                enable => enable_pe,
                x_in => x_chain(i),
                y_in => y_data((i+1)*DATA_WIDTH-1 downto i*DATA_WIDTH),
                m_in => m_data((i+1)*DATA_WIDTH-1 downto i*DATA_WIDTH),
                c_in => c_chain(i),
                x_out => x_chain(i+1),
                y_out => open,
                m_out => open,
                c_out => c_chain(i+1),
                valid_out => pe_valid(i)
            );
        
        -- Extract result from carry chain
        result((i+1)*DATA_WIDTH-1 downto i*DATA_WIDTH) <= 
            c_chain(i+1)(DATA_WIDTH-1 downto 0);
    end generate;
    
    valid <= valid_reg;
    busy <= busy_reg;
    
end structural;
