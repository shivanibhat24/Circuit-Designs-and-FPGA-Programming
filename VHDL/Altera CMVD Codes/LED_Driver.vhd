library ieee;
use ieee.std_logic_1164.all;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
--use ieee.numeric_std.all;


entity LED_DRIVER is
	port
	(
		LCLK		: in std_logic;
		
		LED0		: in std_logic;
		LED1		: in std_logic;
		
		LED_OUT0	: out std_logic;
		LED_OUT1	: out std_logic
	);
end LED_DRIVER;


architecture behav of LED_DRIVER is

	component monoshot
		port
		(
			width_in	: in std_logic_vector(23 downto 0);
			trig_in		: in std_logic;
			clk_in		: in std_logic;
			rst_in		: in std_logic;
			output		: out std_logic
		);
	end component;

begin

	monoshot0 : monoshot
	port map
	(
		width_in	=> X"16E360", --: in std_logic_vector(11 downto 0); -- 30 ms for 50 MHZ lclk
		trig_in		=> LED0, --: in std_logic;
		clk_in		=> LCLK, --: in std_logic;
		rst_in		=> '0', --: in std_logic;
		output		=> LED_OUT0 --: out std_logic 
	);
		
		
	monoshot1 : monoshot
	port map
	(
		width_in	=> X"16E360", --: in std_logic_vector(11 downto 0);
		trig_in		=> LED1, --: in std_logic;
		clk_in		=> LCLK, --: in std_logic;
		rst_in		=> '0', --: in std_logic;
		output		=> LED_OUT1 --: out std_logic 
	);
	
end behav;
