------------------------------------------------------------
-- RAM logic from quartus
------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE work.CMVD_DAQ_PKG.all;
ENTITY ram_infer IS
   PORT
   (
      clock         : IN   std_logic;
      data          : IN   std_logic_vector (15 DOWNTO 0);
      write_address : IN   integer RANGE 0 to FIFO_depth-1;
      read_address  : IN   integer RANGE 0 to FIFO_depth-1;
      we            : IN   std_logic;
	  re            : IN   std_logic;                          ---  read enable 
      q             : OUT  std_logic_vector (15 DOWNTO 0)
   );
END ram_infer;
ARCHITECTURE rtl OF ram_infer IS
   TYPE mem IS ARRAY(FIFO_depth-1 downto 0) OF std_logic_vector(15 DOWNTO 0);
   SIGNAL ram_block : mem;
   
	--attribute ramstyle : string;
	--attribute ramstyle of ram_block : signal is "logic"; -- implement the ram using fpga logic
   
BEGIN
   PROCESS (clock)
   BEGIN
      IF (clock'event AND clock = '1') THEN
         IF (we = '0') THEN
            ram_block(write_address) <= data;
         END IF;
			q <= ram_block(read_address);
		END IF;
   END PROCESS;
END rtl;
