library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity aes_round is
    Port ( 
        clk         : in  STD_LOGIC;
        reset       : in  STD_LOGIC;
        data_in     : in  STD_LOGIC_VECTOR(127 downto 0);
        round_key   : in  STD_LOGIC_VECTOR(127 downto 0);
        data_out    : out STD_LOGIC_VECTOR(127 downto 0);
        is_last_round : in STD_LOGIC
    );
end aes_round;

architecture Behavioral of aes_round is
    -- Component declarations
    component sbox
        Port ( 
            data_in  : in  STD_LOGIC_VECTOR (7 downto 0);
            data_out : out STD_LOGIC_VECTOR (7 downto 0)
        );
    end component;

    -- Internal signals
    signal sub_bytes_out  : STD_LOGIC_VECTOR(127 downto 0);
    signal shift_rows_out : STD_LOGIC_VECTOR(127 downto 0);
    signal mix_cols_out   : STD_LOGIC_VECTOR(127 downto 0);
    signal round_out      : STD_LOGIC_VECTOR(127 downto 0);

    -- S-Box instantiation (array of 16 S-Boxes)
    type sbox_array is array(0 to 15) of STD_LOGIC_VECTOR(7 downto 0);
    signal sbox_outputs : sbox_array;

begin
    -- Generate S-Boxes for SubBytes
    sbox_gen: for i in 0 to 15 generate
        sbox_inst: sbox
        port map (
            data_in  => data_in((i+1)*8-1 downto i*8),
            data_out => sbox_outputs(i)
        );
    end generate;

    -- SubBytes stage (S-Box substitution)
    process(sbox_outputs)
    begin
        for i in 0 to 15 loop
            sub_bytes_out((i+1)*8-1 downto i*8) <= sbox_outputs(i);
        end loop;
    end process;

    -- ShiftRows stage
    process(sub_bytes_out)
    begin
        -- First row (no shift)
        shift_rows_out(7 downto 0)   <= sub_bytes_out(7 downto 0);
        shift_rows_out(15 downto 8)  <= sub_bytes_out(15 downto 8);
        shift_rows_out(23 downto 16) <= sub_bytes_out(23 downto 16);
        shift_rows_out(31 downto 24) <= sub_bytes_out(31 downto 24);
        
        -- Second row (1-byte left shift)
        shift_rows_out(39 downto 32) <= sub_bytes_out(47 downto 40);
        shift_rows_out(47 downto 40) <= sub_bytes_out(55 downto 48);
        shift_rows_out(55 downto 48) <= sub_bytes_out(63 downto 56);
        shift_rows_out(63 downto 56) <= sub_bytes_out(39 downto 32);
        
        -- Third row (2-byte left shift)
        shift_rows_out(71 downto 64) <= sub_bytes_out(87 downto 80);
        shift_rows_out(79 downto 72) <= sub_bytes_out(95 downto 88);
        shift_rows_out(87 downto 80) <= sub_bytes_out(103 downto 96);
        shift_rows_out(95 downto 88) <= sub_bytes_out(71 downto 64);
        
        -- Fourth row (3-byte left shift)
        shift_rows_out(103 downto 96)  <= sub_bytes_out(127 downto 120);
        shift_rows_out(111 downto 104) <= sub_bytes_out(7 downto 0);
        shift_rows_out(119 downto 112) <= sub_bytes_out(15 downto 8);
        shift_rows_out(127 downto 120) <= sub_bytes_out(23 downto 16);
    end process;

    -- MixColumns stage (simplified matrix multiplication)
    process(shift_rows_out)
        variable temp : STD_LOGIC_VECTOR(7 downto 0);
        variable col  : STD_LOGIC_VECTOR(31 downto 0);
    begin
        for i in 0 to 3 loop
            col := shift_rows_out((i+1)*32-1 downto i*32);
            
            -- Simplified MixColumns (placeholder implementation)
            -- Actual implementation would involve Galois Field multiplication
            mix_cols_out((i+1)*32-1 downto i*32) <= col xor 
                                                    (col(30 downto 0) & col(31)) xor
                                                    (col(31) & col(30 downto 1));
        end loop;
    end process;

    -- Final AddRoundKey stage
    process(clk, reset)
    begin
        if reset = '1' then
            data_out <= (others => '0');
        elsif rising_edge(clk) then
            -- If it's the last round, skip MixColumns
            if is_last_round = '1' then
                round_out <= sub_bytes_out xor round_key;
            else
                round_out <= mix_cols_out xor round_key;
            end if;
            
            data_out <= round_out;
        end if;
    end process;
end Behavioral;
