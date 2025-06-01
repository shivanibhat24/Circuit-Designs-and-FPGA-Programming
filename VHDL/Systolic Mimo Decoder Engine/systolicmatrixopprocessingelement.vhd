-- ==============================================================================
-- Systolic Processing Element for Matrix Operations
-- ==============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.mimo_decoder_pkg.all;

entity systolic_pe is
    port (
        clk         : in  std_logic;
        rst         : in  std_logic;
        enable      : in  std_logic;
        
        -- Data inputs
        a_in        : in  complex_fixed;
        b_in        : in  complex_fixed;
        c_in        : in  complex_fixed;
        
        -- Control signals
        mode        : in  std_logic_vector(1 downto 0); -- 00: mult-add, 01: div, 10: identity
        
        -- Data outputs
        a_out       : out complex_fixed;
        b_out       : out complex_fixed;
        c_out       : out complex_fixed;
        result      : out complex_fixed;
        
        -- Status
        valid_out   : out std_logic
    );
end entity;

architecture behavioral of systolic_pe is
    signal a_reg, b_reg, c_reg : complex_fixed;
    signal mult_result : complex_fixed;
    signal div_result : complex_fixed;
    signal final_result : complex_fixed;
    signal valid_reg : std_logic;
    
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                a_reg <= complex_zero;
                b_reg <= complex_zero;
                c_reg <= complex_zero;
                valid_reg <= '0';
            elsif enable = '1' then
                a_reg <= a_in;
                b_reg <= b_in;
                c_reg <= c_in;
                valid_reg <= '1';
            else
                valid_reg <= '0';
            end if;
        end if;
    end process;
    
    -- Multiplication
    mult_result <= complex_mult(a_reg, b_reg);
    
    -- Division (simplified - in practice would use CORDIC or Newton-Raphson)
    process(b_reg)
        variable denom_mag_sq : sfixed(DATA_WIDTH-1 downto -FRAC_WIDTH);
    begin
        denom_mag_sq := b_reg.re * b_reg.re + b_reg.im * b_reg.im;
        if denom_mag_sq /= 0 then
            div_result.re <= (a_reg.re * b_reg.re + a_reg.im * b_reg.im) / denom_mag_sq;
            div_result.im <= (a_reg.im * b_reg.re - a_reg.re * b_reg.im) / denom_mag_sq;
        else
            div_result <= complex_zero;
        end if;
    end process;
    
    -- Mode selection
    process(mode, mult_result, div_result, c_reg, a_reg)
    begin
        case mode is
            when "00" => -- Multiply-accumulate
                final_result <= complex_add(mult_result, c_reg);
            when "01" => -- Division
                final_result <= div_result;
            when "10" => -- Pass-through/Identity
                final_result <= a_reg;
            when others =>
                final_result <= complex_zero;
        end case;
    end process;
    
    -- Outputs
    a_out <= a_reg;
    b_out <= b_reg;
    c_out <= c_reg;
    result <= final_result;
    valid_out <= valid_reg;
    
end architecture;
