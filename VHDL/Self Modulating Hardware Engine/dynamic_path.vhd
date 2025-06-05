-- =========================================================================
-- DYNAMIC LOGIC PATH MODULE
-- =========================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.self_mod_pkg.all;

entity dynamic_path is
    port (
        clk        : in  std_logic;
        rst        : in  std_logic;
        data_in    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        key_in     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        operation  : in  operation_t;
        enable     : in  std_logic;
        data_out   : out std_logic_vector(DATA_WIDTH-1 downto 0);
        valid_out  : out std_logic
    );
end entity;

architecture behavioral of dynamic_path is
    signal result : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal mult_temp : std_logic_vector(2*DATA_WIDTH-1 downto 0);
    signal valid_reg : std_logic;
begin
    process(clk, rst)
    begin
        if rst = '1' then
            data_out <= (others => '0');
            valid_reg <= '0';
        elsif rising_edge(clk) then
            if enable = '1' then
                case operation is
                    when OP_XOR =>
                        result <= data_in xor key_in;
                    when OP_AND =>
                        result <= data_in and key_in;
                    when OP_OR =>
                        result <= data_in or key_in;
                    when OP_ADD =>
                        result <= std_logic_vector(unsigned(data_in) + unsigned(key_in));
                    when OP_SUB =>
                        result <= std_logic_vector(unsigned(data_in) - unsigned(key_in));
                    when OP_MUL =>
                        mult_temp <= std_logic_vector(unsigned(data_in(15 downto 0)) * 
                                                    unsigned(key_in(15 downto 0)));
                        result <= mult_temp(DATA_WIDTH-1 downto 0);
                    when OP_ROT =>
                        result <= data_in(DATA_WIDTH-5 downto 0) & data_in(DATA_WIDTH-1 downto DATA_WIDTH-4);
                    when OP_DUMMY =>
                        -- Dummy operation with same timing characteristics
                        result <= not (data_in xor key_in);
                    when others =>
                        result <= data_in;
                end case;
                data_out <= result;
                valid_reg <= '1';
            else
                valid_reg <= '0';
            end if;
        end if;
    end process;
    
    valid_out <= valid_reg;
end architecture;
