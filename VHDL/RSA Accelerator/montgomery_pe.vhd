-- =============================================================================
-- MONTGOMERY PROCESSING ELEMENT
-- =============================================================================
-- File: montgomery_pe.vhd
-- Single processing element for Montgomery multiplication

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.rsa_pkg.all;

entity montgomery_pe is
    generic (
        DATA_WIDTH : integer := PE_DATA_WIDTH
    );
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        enable    : in  std_logic;
        x_in      : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        y_in      : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        m_in      : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        c_in      : in  std_logic_vector(DATA_WIDTH downto 0);
        x_out     : out std_logic_vector(DATA_WIDTH-1 downto 0);
        y_out     : out std_logic_vector(DATA_WIDTH-1 downto 0);
        m_out     : out std_logic_vector(DATA_WIDTH-1 downto 0);
        c_out     : out std_logic_vector(DATA_WIDTH downto 0);
        valid_out : out std_logic
    );
end montgomery_pe;

architecture behavioral of montgomery_pe is
    signal s_temp   : unsigned(DATA_WIDTH+1 downto 0);
    signal q_temp   : std_logic;
    signal x_reg    : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal y_reg    : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal m_reg    : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal c_reg    : std_logic_vector(DATA_WIDTH downto 0);
    signal valid_reg : std_logic;
    
begin
    process(clk)
        variable mult_temp : unsigned(DATA_WIDTH downto 0);
        variable add_temp  : unsigned(DATA_WIDTH+1 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                x_reg <= (others => '0');
                y_reg <= (others => '0');
                m_reg <= (others => '0');
                c_reg <= (others => '0');
                valid_reg <= '0';
                s_temp <= (others => '0');
                q_temp <= '0';
            elsif enable = '1' then
                -- Montgomery multiplication step
                -- s = c + x[0] * y
                if x_in(0) = '1' then
                    mult_temp := '0' & unsigned(y_in);
                else
                    mult_temp := (others => '0');
                end if;
                
                add_temp := ('0' & unsigned(c_in)) + mult_temp;
                q_temp <= add_temp(0);
                
                -- s = s + q * m
                if add_temp(0) = '1' then
                    s_temp <= add_temp + ('0' & unsigned(m_in));
                else
                    s_temp <= add_temp;
                end if;
                
                -- Pipeline registers
                x_reg <= '0' & x_in(DATA_WIDTH-1 downto 1);
                y_reg <= y_in;
                m_reg <= m_in;
                c_reg <= std_logic_vector(s_temp(DATA_WIDTH+1 downto 1));
                valid_reg <= '1';
            else
                valid_reg <= '0';
            end if;
        end if;
    end process;
    
    x_out <= x_reg;
    y_out <= y_reg;
    m_out <= m_reg;
    c_out <= c_reg;
    valid_out <= valid_reg;
    
end behavioral;
