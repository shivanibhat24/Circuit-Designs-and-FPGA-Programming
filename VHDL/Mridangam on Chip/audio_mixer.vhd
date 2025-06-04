-- Audio Mixer Component
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_SIGNED.ALL;

entity audio_mixer is
    generic (
        NUM_INPUTS : integer := 8
    );
    Port (
        clk        : in  STD_LOGIC;
        reset      : in  STD_LOGIC;
        inputs     : in  STD_LOGIC_VECTOR((16 * NUM_INPUTS) - 1 downto 0);
        output     : out STD_LOGIC_VECTOR(15 downto 0)
    );
end audio_mixer;

architecture Behavioral of audio_mixer is
    signal mix_sum : signed(19 downto 0) := (others => '0');
begin

    process(clk, reset)
        variable temp_sum : signed(19 downto 0);
    begin
        if reset = '1' then
            mix_sum <= (others => '0');
        elsif rising_edge(clk) then
            temp_sum := (others => '0');
            
            -- Sum all inputs
            for i in 0 to NUM_INPUTS-1 loop
                temp_sum := temp_sum + 
                    resize(signed(inputs((i+1)*16-1 downto i*16)), 20);
            end loop;
            
            mix_sum <= temp_sum;
        end if;
    end process;
    
    -- Scale down and saturate
    process(mix_sum)
    begin
        if mix_sum > 32767 then
            output <= std_logic_vector(to_signed(32767, 16));
        elsif mix_sum < -32768 then
            output <= std_logic_vector(to_signed(-32768, 16));
        else
            output <= std_logic_vector(mix_sum(15 downto 0));
        end if;
    end process;

end Behavioral;
