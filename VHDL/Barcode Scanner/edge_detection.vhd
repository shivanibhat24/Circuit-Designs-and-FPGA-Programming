library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity grayscale_converter is
    Port ( 
        clk         : in STD_LOGIC;
        reset       : in STD_LOGIC;
        rgb_data    : in STD_LOGIC_VECTOR(23 downto 0);  -- 24-bit RGB
        gray_data   : out STD_LOGIC_VECTOR(7 downto 0)   -- 8-bit Grayscale
    );
end grayscale_converter;

architecture Behavioral of grayscale_converter is
    -- Conversion constants (fixed-point representation)
    constant COEFF_R : unsigned(9 downto 0) := to_unsigned(integer(0.299 * 1024), 10);
    constant COEFF_G : unsigned(9 downto 0) := to_unsigned(integer(0.587 * 1024), 10);
    constant COEFF_B : unsigned(9 downto 0) := to_unsigned(integer(0.114 * 1024), 10);

begin
    process(clk, reset)
        variable red   : unsigned(9 downto 0);
        variable green : unsigned(9 downto 0);
        variable blue  : unsigned(9 downto 0);
        variable gray_calc : unsigned(19 downto 0);
    begin
        if reset = '1' then
            gray_data <= (others => '0');
        elsif rising_edge(clk) then
            -- Extract RGB components
            red   := unsigned('0' & rgb_data(23 downto 16)) * COEFF_R;
            green := unsigned('0' & rgb_data(15 downto 8))  * COEFF_G;
            blue  := unsigned('0' & rgb_data(7 downto 0))   * COEFF_B;
            
            -- Calculate grayscale with fixed-point multiplication
            gray_calc := red + green + blue;
            
            -- Normalize and convert to 8-bit
            gray_data <= std_logic_vector(gray_calc(17 downto 10));
        end if;
    end process;
end Behavioral;
