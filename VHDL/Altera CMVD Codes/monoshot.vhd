library ieee;
use ieee.std_logic_1164.all;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity monoshot is
	--generic (width_gen : std_logic_vector(11 downto 0) := X"240"); -- default is 7
	port
	(
		width_in: in std_logic_vector(23 downto 0);
		trig_in	: in std_logic;
		clk_in	: in std_logic;
		rst_in	: in std_logic;
		output	: out std_logic
	);
end monoshot;
	
architecture monoshot_behav of monoshot is
	signal rst_sig		: std_logic;
	signal mono_rst_sig	: std_logic;
	signal count_sig	: std_logic_vector (23 downto 0);
	signal out_sig		: std_logic;
begin
	process(trig_in, rst_in, rst_sig)
	begin
		if(rst_in = '1' or rst_sig = '1') then
			out_sig <= '0';
		elsif(trig_in'event and trig_in = '1') then
			out_sig <= '1';
		end if;
	end process;
	
	process(clk_in, rst_in, rst_sig)
	begin
		if(rst_in = '1' or rst_sig = '1') then
			count_sig <= (others => '0');
			rst_sig <= '0';
		elsif(clk_in'event and clk_in = '0') then
			if(out_sig = '1') then
				count_sig <= count_sig + 1;
			end if;
			if(count_sig = width_in ) then
				rst_sig <= '1';
			end if;
		end if;
	end process;
	
	output <= out_sig;
end monoshot_behav;


library ieee;
use ieee.std_logic_1164.all;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity mono is
port (clk_in, trig_in : in std_logic;
		rst_inp: in std_logic;
		output : out std_logic;
		width_in : in std_logic_vector(31 downto 0)
		);
end mono;

architecture ab of mono is
	signal rst_in : std_logic := not rst_inp;
	signal rst_sig		: std_logic;
	signal mono_rst_sig	: std_logic;
	signal count_sig	: std_logic_vector (31 downto 0);
	signal out_sig		: std_logic;
begin
	process(trig_in, rst_in, rst_sig)
	begin
		if(rst_in = '1' or rst_sig = '1') then
			out_sig <= '0';
		elsif(trig_in'event and trig_in = '1') then
			out_sig <= '1';
		end if;
	end process;
	
	process(clk_in, rst_in, rst_sig)
	begin
		if(rst_in = '1' or rst_sig = '1') then
			count_sig <= (others => '0');
			rst_sig <= '0';
		elsif(clk_in'event and clk_in = '0') then
			if(out_sig = '1') then
				count_sig <= count_sig + 1;
			end if;
			if(count_sig = width_in ) then
				rst_sig <= '1';
			end if;
		end if;
	end process;
	
	output <= out_sig;
end ab;

-------------------------------------------------------------------------------------
-- Synchronised monoshot, i.e. output synced with clk
-------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity sync_monoshot is
	--generic (width_gen : std_logic_vector(11 downto 0) := X"240"); -- default is 7
	port
	(
		width_in: in std_logic_vector(15 downto 0);
		trig_in	: in std_logic;
		clk_in	: in std_logic;
		rst_in	: in std_logic;
		output	: out std_logic
	);
end sync_monoshot;

architecture behav of sync_monoshot is
	signal out_sig		: std_logic;
begin	
	process(rst_in, clk_in)
		variable count_sig	: std_logic_vector (15 downto 0);
	begin
		if(rst_in = '1') then
			count_sig := (others => '0');
			out_sig <= '0';
		elsif(clk_in'event and clk_in = '0') then
			if(trig_in = '1') then
				out_sig <= '1';
			end if;
			if(out_sig = '1') then
				count_sig := count_sig + 1;
			end if;
			if(count_sig = width_in) then
				out_sig <= '0';
				count_sig := (others => '0');
			end if;
		end if;
	end process;
	
	output <= out_sig;
end behav;

---------------------------------------------------------------------
-- sync monoshot non-retriggered
---------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity sync_monoshot_nrt is
	port
	(
		width_in: in std_logic_vector(15 downto 0);
		trig_in	: in std_logic;
		clk_in	: in std_logic;
		rst_in	: in std_logic;
		output	: out std_logic
	);
end sync_monoshot_nrt;
	
architecture monoshot_behav of sync_monoshot_nrt is
	signal rst_sig		: std_logic;
	signal mono_rst_sig	: std_logic;
	signal count_sig	: std_logic_vector (15 downto 0);
	signal out_sig		: std_logic;
	signal out_enable_sig: std_logic;
begin
	process(trig_in, rst_in, rst_sig)
	begin
		if(rst_in = '1' or rst_sig = '1') then
			out_enable_sig <= '0';
		elsif(trig_in'event and trig_in = '1') then
			out_enable_sig <= '1';
		end if;
	end process;
	
	process(clk_in, rst_in, rst_sig)
	begin
		if(rst_in = '1' or rst_sig = '1') then
			out_sig <= '0';
			count_sig <= (others => '0');
			rst_sig <= '0';
		elsif(clk_in'event and clk_in = '0') then
			if(out_enable_sig = '1') then
				out_sig <= '1';
			end if;
			if(out_sig = '1') then
				count_sig <= count_sig + 1;
			end if;
			if(count_sig = width_in - 1 ) then
				rst_sig <= '1';
			end if;
		end if;
	end process;
	
	output <= out_sig;
end monoshot_behav;



---------------------------------------------------------------------
-- monoshot 5 clocks -- 100ns
---------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity monoshot_100ns is
	port
	(
		--width_in: in std_logic_vector(11 downto 0);
		trig_in	: in std_logic;
		clk_in	: in std_logic;
		rst_in	: in std_logic;
		output	: out std_logic
	);
end monoshot_100ns;
	
architecture monoshot_behav of monoshot_100ns is
	signal rst_sig		: std_logic;
	signal mono_rst_sig	: std_logic;
	signal count_sig	: std_logic_vector (11 downto 0);
	signal out_sig		: std_logic;
begin
	process(trig_in, rst_in, rst_sig)
	begin
		if(rst_in = '1' or rst_sig = '1') then
			out_sig <= '0';
		elsif(trig_in'event and trig_in = '1') then
			out_sig <= '1';
		end if;
	end process;
	
	process(clk_in, rst_in, rst_sig)
	begin
		if(rst_in = '1' or rst_sig = '1') then
			count_sig <= (others => '0');
			rst_sig <= '0';
		elsif(clk_in'event and clk_in = '0') then
			if(out_sig = '1') then
				count_sig <= count_sig + 1;
			end if;
			if(count_sig = 6) then
				rst_sig <= '1';
			end if;
		end if;
	end process;
	
	output <= out_sig;
end monoshot_behav;


---------------------------------------------------------------------
-- monoshot 500000 clocks -- 10ms   from 20ns clock
---------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity monoshot_10ms is
	port
	(
		--width_in: in std_logic_vector(11 downto 0);
		trig_in	: in std_logic;
		clk_in	: in std_logic;
		rst_in	: in std_logic;
		output	: out std_logic
	);
end monoshot_10ms;
	
architecture monoshot_behav of monoshot_10ms is
	signal rst_sig		: std_logic;
	signal mono_rst_sig	: std_logic;
	signal count_sig	: std_logic_vector (19 downto 0);
	signal out_sig		: std_logic;
begin
	process(trig_in, rst_in, rst_sig)
	begin
		if(rst_in = '1' or rst_sig = '1') then
			out_sig <= '0';
		elsif(trig_in'event and trig_in = '1') then
			out_sig <= '1';
		end if;
	end process;
	
	process(clk_in, rst_in, rst_sig)
	begin
		if(rst_in = '1' or rst_sig = '1') then
			count_sig <= (others => '0');
			rst_sig <= '0';
		elsif(clk_in'event and clk_in = '0') then
			if(out_sig = '1') then
				count_sig <= count_sig + 1;
			end if;
			if(count_sig = 500001) then
				rst_sig <= '1';
			end if;
		end if;
	end process;
	
	output <= out_sig;
end monoshot_behav;



