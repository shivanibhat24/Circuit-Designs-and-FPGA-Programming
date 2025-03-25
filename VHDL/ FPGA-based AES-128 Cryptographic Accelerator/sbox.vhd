library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sbox is
    Port ( 
        data_in  : in  STD_LOGIC_VECTOR (7 downto 0);
        data_out : out STD_LOGIC_VECTOR (7 downto 0)
    );
end sbox;

architecture Behavioral of sbox is
    type sbox_array is array (0 to 255) of STD_LOGIC_VECTOR(7 downto 0);
    
    -- Precomputed S-Box lookup table
    constant SBOX : sbox_array := (
        -- S-Box values (first 16 shown for brevity)
        x"63", x"7C", x"77", x"7B", x"F2", x"6B", x"6F", x"C5", 
        x"30", x"01", x"67", x"2B", x"FE", x"D7", x"AB", x"76",
        -- Full 256-entry S-Box would be implemented here
        -- Note: Complete S-Box requires 256 entries
        -- This is a placeholder implementation
        others => x"00"
    );
begin
    -- Synchronous lookup of S-Box value
    process(data_in)
    begin
        data_out <= SBOX(to_integer(unsigned(data_in)));
    end process;
end Behavioral;
