library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.std_logic_unsigned.all;
 
entity vga_controller is
			
	port(
    rst,pclk : in std_logic;
    sw : in std_logic_vector(2 downto 0);
    red : out std_logic_vector(4 downto 0);
    green : out std_logic_vector(5 downto 0);
    blue : out std_logic_vector(4 downto 0);
    h_sync : out std_logic;
    v_sync : out std_logic
		);
		
end entity;
 
architecture behav of vga_controller is
Component design_1_wrapper is
  port (
    clk : out STD_LOGIC;
    locked : out STD_LOGIC;
    pclk : in STD_LOGIC
  );
end component;
 
 
 
	signal h_count : integer range 0 to 801 := 0;
	signal v_count : integer range 0 to 526 := 0;
	signal h_end : std_logic;
	signal v_end : std_logic;
	signal h_active : std_logic;
	signal v_active : std_logic;
	signal s_red : std_logic_vector(4 downto 0);
    signal s_green : std_logic_vector(5 downto 0);
    signal s_blue : std_logic_vector(4 downto 0);
	
	signal clk,locked : std_logic:= '0';
signal count : integer range 0 to 5 := 0;
begin
c1 : design_1_wrapper port map (clk=> clk, locked => locked,pclk=> pclk);
 
 
 
p1 : process(clk) is
	begin
	 if(rising_edge(clk)) then
      if(rst = '1') then
       h_count <= 0;
     elsif(h_end = '1') then
       h_count <= 0;
     else
        h_count <= h_count + 1;
      end if;
    end if;       
end process;
	
 
p2 : process(h_count) is
	begin	
		if(h_count >= 0 and h_count < 96) then
		 h_sync <= '1';
		else
		  h_sync <= '0';
		end if;
		
		if(h_count >= 144 and h_count < 784) then
		  h_active <= '1';
		 else
		  h_active <= '0';
	    end if;
	   
	    if(h_count = 800) then
          h_end <= '1';
         else
          h_end <= '0';
        end if;   
end process;
 
 
p3: process(clk)
begin
if(rising_edge(clk)) then
   if(rst = '1' and locked = '0') then
       v_count <= 0;
    elsif (v_end = '1') then
      v_count <= 0;
    elsif(h_end = '1') then
       v_count <= v_count + 1;
    else 
        null;
   end if;
 end if;
 end process;
 
 
 p4: process(v_count,h_count) begin
 if(v_count >= 0  and v_count < 2) then
     v_sync <= '1';
 else
     v_sync <= '0';
 end if;
 
 if(v_count >= 35  and v_count < 515) then
      v_active <= '1';
  else
      v_active <= '0';
  end if;
  
  if(v_count = 524 and h_count = 799) then
       v_end <= '1';
  else
       v_end <= '0';
  end if;
  end process;
 
p5: process(v_active, h_active)
begin
if(v_active = '1' and h_active = '1') then
case sw is
			when "000" => 
				s_red <= (others => '0');
				s_green <= (others => '0');
				s_blue <= (others => '0');
			when "001" => 
				s_red <= (others => '0');
				s_green <= (others => '0');
				s_blue <= (others => '1');
			when "010" => 
				s_red <= (others => '0');
				s_green <= (others => '1');
				s_blue <= (others => '0');
			when "011" => 
				s_red <= (others => '0');
				s_green <= (others => '1');
				s_blue <= (others => '1');
			when "100" => 
				s_red <= (others => '1');
				s_green <= (others => '0');
				s_blue <= (others => '0');
			when "101" => 
				s_red <= (others => '1');
				s_green <= (others => '0');
				s_blue <= (others => '1');
			when "110" => 
				s_red <= (others => '1');
				s_green <= (others => '1');
				s_blue <= (others => '0');
			when "111" => 
				s_red <= (others => '1');
				s_green <= (others => '1');
				s_blue <= (others => '1');
			when others =>
				null;
		end case;
else
s_red <= (others => '0');
s_green <= (others => '0');
s_blue <= (others => '0');  
 
end if; 
end process;   
 
red <= s_red;
green <= s_green;
blue <= s_blue;
 
end behav;
