-- ==============================================================================
-- Systolic MIMO Decoder Engine
-- Implements ZF/MMSE detection with matrix inversion for massive MIMO systems
-- ==============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.FIXED_PKG.ALL;

-- Package for complex arithmetic and matrix operations
package mimo_decoder_pkg is
    -- Fixed-point configuration
    constant DATA_WIDTH : integer := 16;
    constant FRAC_WIDTH : integer := 12;
    
    -- Complex number type using fixed-point
    type complex_fixed is record
        re : sfixed(DATA_WIDTH-1 downto -FRAC_WIDTH);
        im : sfixed(DATA_WIDTH-1 downto -FRAC_WIDTH);
    end record;
    
    -- Matrix dimensions
    constant MAX_ANTENNAS : integer := 64;  -- Maximum number of antennas
    constant MAX_USERS : integer := 16;     -- Maximum number of users
    
    -- Matrix types
    type complex_matrix is array (natural range <>, natural range <>) of complex_fixed;
    type complex_vector is array (natural range <>) of complex_fixed;
    
    -- Function declarations
    function complex_mult(a, b : complex_fixed) return complex_fixed;
    function complex_add(a, b : complex_fixed) return complex_fixed;
    function complex_sub(a, b : complex_fixed) return complex_fixed;
    function complex_conj(a : complex_fixed) return complex_fixed;
    function complex_zero return complex_fixed;
    function complex_one return complex_fixed;
end package;

package body mimo_decoder_pkg is
    function complex_mult(a, b : complex_fixed) return complex_fixed is
        variable result : complex_fixed;
    begin
        result.re := a.re * b.re - a.im * b.im;
        result.im := a.re * b.im + a.im * b.re;
        return result;
    end function;
    
    function complex_add(a, b : complex_fixed) return complex_fixed is
        variable result : complex_fixed;
    begin
        result.re := a.re + b.re;
        result.im := a.im + b.im;
        return result;
    end function;
    
    function complex_sub(a, b : complex_fixed) return complex_fixed is
        variable result : complex_fixed;
    begin
        result.re := a.re - b.re;
        result.im := a.im - b.im;
        return result;
    end function;
    
    function complex_conj(a : complex_fixed) return complex_fixed is
        variable result : complex_fixed;
    begin
        result.re := a.re;
        result.im := -a.im;
        return result;
    end function;
    
    function complex_zero return complex_fixed is
        variable result : complex_fixed;
    begin
        result.re := (others => '0');
        result.im := (others => '0');
        return result;
    end function;
    
    function complex_one return complex_fixed is
        variable result : complex_fixed;
    begin
        result.re := to_sfixed(1.0, DATA_WIDTH-1, -FRAC_WIDTH);
        result.im := (others => '0');
        return result;
    end function;
end package body;
