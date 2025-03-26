library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity binarization is
    Port ( 
        clk         : in STD_LOGIC;
        reset       : in STD_LOGIC;
        gray_data   : in STD_LOGIC_VECTOR(7 downto 0);
        binary_data : out STD_LOGIC;
        threshold   : out STD_LOGIC_VECTOR(7 downto 0)
    );
end binarization;

architecture Behavioral of binarization is
    -- Histogram for Otsu thresholding
    type histogram_array is array(0 to 255) of unsigned(31 downto 0);
    signal histogram : histogram_array := (others => (others => '0'));
    
    -- State machine for thresholding
    type otsu_state is (COLLECT, COMPUTE, THRESHOLD);
    signal current_state : otsu_state := COLLECT;
    
    -- Computation variables
    signal total_pixels : unsigned(31 downto 0) := (others => '0');
    signal otsu_threshold : unsigned(7 downto 0) := (others => '0');

begin
    process(clk, reset)
        variable max_var : unsigned(31 downto 0);
        variable w0, w1 : unsigned(31 downto 0);
        variable mean0, mean1 : unsigned(31 downto 0);
        variable inter_var : unsigned(31 downto 0);
    begin
        if reset = '1' then
            current_state <= COLLECT;
            histogram <= (others => (others => '0'));
            total_pixels <= (others => '0');
            otsu_threshold <= (others => '0');
            binary_data <= '0';
        elsif rising_edge(clk) then
            case current_state is
                when COLLECT =>
                    -- Collect histogram
                    histogram(to_integer(unsigned(gray_data))) <= 
                        histogram(to_integer(unsigned(gray_data))) + 1;
                    total_pixels <= total_pixels + 1;
                    
                    -- Transition to compute when histogram is full
                    if total_pixels = to_unsigned(256*256, 32) then
                        current_state <= COMPUTE;
                    end if;

                when COMPUTE =>
                    -- Otsu's method for optimal thresholding
                    max_var := (others => '0');
                    for t in 1 to 254 loop
                        w0 := (others => '0');
                        w1 := (others => '0');
                        mean0 := (others => '0');
                        mean1 := (others => '0');

                        -- Compute class probabilities and means
                        for i in 0 to t loop
                            w0 := w0 + histogram(i);
                            mean0 := mean0 + (histogram(i) * to_unsigned(i, 32));
                        end loop;

                        for i in t+1 to 255 loop
                            w1 := w1 + histogram(i);
                            mean1 := mean1 + (histogram(i) * to_unsigned(i, 32));
                        end loop;

                        -- Compute variance between classes
                        if w0 /= 0 and w1 /= 0 then
                            mean0 := mean0 / w0;
                            mean1 := mean1 / w1;
                            inter_var := w0 * w1 * (mean0 - mean1)**2;

                            -- Update max variance and threshold
                            if inter_var > max_var then
                                max_var := inter_var;
                                otsu_threshold <= to_unsigned(t, 8);
                            end if;
                        end if;
                    end loop;

                    current_state <= THRESHOLD;

                when THRESHOLD =>
                    -- Apply computed threshold
                    if unsigned(gray_data) > otsu_threshold then
                        binary_data <= '1';
                    else
                        binary_data <= '0';
                    end if;

                    threshold <= std_logic_vector(otsu_threshold);
            end case;
        end if;
    end process;
end Behavioral;
