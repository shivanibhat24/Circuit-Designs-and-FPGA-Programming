library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.std_logic_unsigned.all;
 
entity uart_top is
    Port ( start,clk : in STD_LOGIC;
           tx : out STD_LOGIC);
end uart_top;
 
architecture Behavioral of uart_top is
signal uart_clk_timer : integer range 0 to 10416 := 0;
signal bit_count : integer range 0 to 11 := 0;
signal txt : std_logic := '0';
signal tx_data : std_logic_vector(9 downto 0);
signal count : integer range 0 to 10417 := 0;
signal bit_done : std_logic := '0';
 
type state_type is (rdy,load_data,check_count);
signal state : state_type := rdy;
begin
 
Actual_Data_Transmission: process(clk)
begin
if(rising_edge(clk)) then
    case(state) is
     when rdy => 
      if(start = '0') then
          state <= rdy;
     else
          state <= load_data;
          tx_data <=  ( '1' & X"41" & '0' );
     end if;
    
      when load_data => 
        txt <= tx_data(bit_count);        
         bit_count <= bit_count + 1;        
        state <= check_count;
         
       when check_count => 
       if(bit_done = '1') then
          if(bit_count < 10 ) then
             state <= load_data;
          else
              bit_count <= 0;
              state <= rdy;
          end if;
        else
             state <= check_count;
        end if;
       
       when others => state <= rdy;
    end case;
end if;
end process;
 
 
Generate_Baud_Rate: process(clk)
begin
if(rising_Edge(clk)) then
    if(state = rdy) then
       count <= 0;
     elsif (count < 10416) then
       bit_done <= '0';
       count <= count + 1;
      else
       count <= 0;
       bit_done <= '1';
   end if;
end if;
end process;    
 
tx <= txt;
end Behavioral;
