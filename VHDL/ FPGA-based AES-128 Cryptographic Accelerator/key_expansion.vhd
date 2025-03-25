library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity key_expansion is
    Generic (
        KEY_SIZE : integer := 128  -- 128, 192, or 256 bits
    );
    Port ( 
        clk        : in  STD_LOGIC;
        reset      : in  STD_LOGIC;
        key_in     : in  STD_LOGIC_VECTOR(KEY_SIZE-1 downto 0);
        round_key  : out STD_LOGIC_VECTOR(127 downto 0);
        valid      : out STD_LOGIC
    );
end key_expansion;

architecture Behavioral of key_expansion is
    -- Rcon (Round Constant) array
    type rcon_array is array (0 to 10) of STD_LOGIC_VECTOR(7 downto 0);
    constant RCON : rcon_array := (
        x"8D", x"01", x"02", x"04", x"08", x"10", 
        x"20", x"40", x"80", x"1B", x"36"
    );
    
    -- Internal signals for key scheduling
    signal expanded_key : STD_LOGIC_VECTOR(4*KEY_SIZE-1 downto 0);
    signal round_count  : integer range 0 to 10;
    
    -- S-Box function (simplified, would typically use separate S-Box module)
    function sbox_lookup(input : STD_LOGIC_VECTOR(7 downto 0)) return STD_LOGIC_VECTOR is
        variable sbox_value : STD_LOGIC_VECTOR(7 downto 0);
    begin
        -- Placeholder S-Box lookup (would match full S-Box implementation)
        case input is
            when x"00" => sbox_value := x"63";
            when x"01" => sbox_value := x"7C";
            -- More S-Box entries would be added here
            when others => sbox_value := input;
        end case;
        return sbox_value;
    end function;
    
    -- RotWord function for key scheduling
    function rot_word(input : STD_LOGIC_VECTOR(31 downto 0)) return STD_LOGIC_VECTOR is
    begin
        return input(23 downto 0) & input(31 downto 24);
    end function;
    
    -- SubWord function for key scheduling
    function sub_word(input : STD_LOGIC_VECTOR(31 downto 0)) return STD_LOGIC_VECTOR is
        variable result : STD_LOGIC_VECTOR(31 downto 0);
    begin
        result(31 downto 24) := sbox_lookup(input(31 downto 24));
        result(23 downto 16) := sbox_lookup(input(23 downto 16));
        result(15 downto 8)  := sbox_lookup(input(15 downto 8));
        result(7 downto 0)   := sbox_lookup(input(7 downto 0));
        return result;
    end function;
begin
    -- Key Expansion Process
    process(clk, reset)
        variable temp : STD_LOGIC_VECTOR(31 downto 0);
    begin
        if reset = '1' then
            expanded_key <= (others => '0');
            round_count <= 0;
            valid <= '0';
        elsif rising_edge(clk) then
            -- Initial key loading
            if round_count = 0 then
                expanded_key(KEY_SIZE-1 downto 0) <= key_in;
            end if;
            
            -- Key schedule for AES-128
            if KEY_SIZE = 128 then
                if round_count < 10 then
                    -- Generate next round key
                    temp := expanded_key((round_count*128)+127 downto (round_count*128)+96);
                    temp := sub_word(rot_word(temp)) xor 
                            x"000000" & RCON(round_count+1);
                    
                    -- XOR with previous round key words
                    for i in 0 to 3 loop
                        expanded_key((round_count+1)*128 + (i*32) + 31 downto 
                                     (round_count+1)*128 + (i*32)) := 
                            expanded_key((round_count*128) + (i*32) + 31 downto 
                                         (round_count*128) + (i*32)) xor temp;
                        temp := expanded_key((round_count+1)*128 + (i*32) + 31 downto 
                                             (round_count+1)*128 + (i*32));
                    end loop;
                    
                    -- Output current round key
                    round_key <= expanded_key((round_count*128) + 127 downto (round_count*128));
                    
                    round_count <= round_count + 1;
                    valid <= '1';
                end if;
            end if;
        end if;
    end process;
end Behavioral;
