library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity aes_top is
    Generic (
        KEY_SIZE : integer := 128  -- 128, 192, or 256 bits
    );
    Port ( 
        clk         : in  STD_LOGIC;
        reset       : in  STD_LOGIC;
        data_in     : in  STD_LOGIC_VECTOR(127 downto 0);
        key_in      : in  STD_LOGIC_VECTOR(KEY_SIZE-1 downto 0);
        data_out    : out STD_LOGIC_VECTOR(127 downto 0);
        valid       : out STD_LOGIC
    );
end aes_top;

architecture Behavioral of aes_top is
    -- Component declarations
    component key_expansion
        Generic (
            KEY_SIZE : integer
        );
        Port ( 
            clk        : in  STD_LOGIC;
            reset      : in  STD_LOGIC;
            key_in     : in  STD_LOGIC_VECTOR(KEY_SIZE-1 downto 0);
            round_key  : out STD_LOGIC_VECTOR(127 downto 0);
            valid      : out STD_LOGIC
        );
    end component;

    component aes_round
        Port ( 
            clk         : in  STD_LOGIC;
            reset       : in  STD_LOGIC;
            data_in     : in  STD_LOGIC_VECTOR(127 downto 0);
            round_key   : in  STD_LOGIC_VECTOR(127 downto 0);
            data_out    : out STD_LOGIC_VECTOR(127 downto 0);
            is_last_round : in STD_LOGIC
        );
    end component;

    -- Internal signals
    type round_key_array is array(0 to 10) of STD_LOGIC_VECTOR(127 downto 0);
    signal round_keys : round_key_array;
    
    type state_array is array(0 to 10) of STD_LOGIC_VECTOR(127 downto 0);
    signal round_states : state_array;
    
    signal key_expansion_valid : STD_LOGIC;
    signal current_round : integer range 0 to 10;
    signal encryption_done : STD_LOGIC;

begin
    -- Key Expansion Module
    key_exp_inst: key_expansion
    generic map (
        KEY_SIZE => KEY_SIZE
    )
    port map (
        clk => clk,
        reset => reset,
        key_in => key_in,
        round_key => round_keys(0),
        valid => key_expansion_valid
    );

    -- Initial AddRoundKey
    process(clk, reset)
    begin
        if reset = '1' then
            round_states(0) <= (others => '0');
            current_round <= 0;
            encryption_done <= '0';
            valid <= '0';
        elsif rising_edge(clk) then
            if key_expansion_valid = '1' then
                -- Initial round: XOR with first round key
                round_states(0) <= data_in xor round_keys(0);
                current_round <= 1;
            end if;
        end if;
    end process;

    -- Generate AES Rounds
    round_gen: for i in 1 to 9 generate
        round_inst: aes_round
        port map (
            clk => clk,
            reset => reset,
            data_in => round_states(i-1),
            round_key => round_keys(i),
            data_out => round_states(i),
            is_last_round => '0'
        );
    end generate;

    -- Final Round (without MixColumns)
    final_round_inst: aes_round
    port map (
        clk => clk,
        reset => reset,
        data_in => round_states(9),
        round_key => round_keys(10),
        data_out => data_out,
        is_last_round => '1'
    );

    -- Encryption Completion
    process(clk, reset)
    begin
        if reset = '1' then
            valid <= '0';
        elsif rising_edge(clk) then
            -- Set valid flag when encryption is complete
            if current_round = 10 then
                valid <= '1';
                encryption_done <= '1';
            end if;
        end if;
    end process;
end Behavioral;
