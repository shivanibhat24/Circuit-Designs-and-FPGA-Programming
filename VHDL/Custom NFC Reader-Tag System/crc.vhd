library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity nfc_crc is
    Port (
        clk         : in  STD_LOGIC;
        rst         : in  STD_LOGIC;
        data_in     : in  STD_LOGIC;
        data_valid  : in  STD_LOGIC;
        crc_init    : in  STD_LOGIC;
        crc_out     : out STD_LOGIC_VECTOR(15 downto 0)
    );
end nfc_crc;

architecture Behavioral of nfc_crc is
    -- CRC-16 for ISO/IEC 14443 Type A (polynomial: x^16 + x^12 + x^5 + 1)
    signal crc_reg : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
begin
    -- CRC calculation process
    process(clk, rst)
        variable feedback : STD_LOGIC;
    begin
        if rst = '1' then
            crc_reg <= (others => '0');
        elsif rising_edge(clk) then
            if crc_init = '1' then
                crc_reg <= (others => '0'); -- Initialize CRC
            elsif data_valid = '1' then
                -- Calculate feedback bit
                feedback := data_in xor crc_reg(15);
                
                -- Shift register with feedback
                crc_reg <= crc_reg(14 downto 0) & '0';
                
                -- Apply polynomial taps (x^16 + x^12 + x^5 + 1)
                if feedback = '1' then
                    crc_reg(12) <= crc_reg(12) xor feedback;
                    crc_reg(5) <= crc_reg(5) xor feedback;
                    crc_reg(0) <= crc_reg(0) xor feedback;
                end if;
            end if;
        end if;
    end process;
    
    -- Output assignment
    crc_out <= crc_reg;
end Behavioral;
