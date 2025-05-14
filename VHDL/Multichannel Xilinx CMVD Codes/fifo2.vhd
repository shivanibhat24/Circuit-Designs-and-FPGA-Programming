LIbrary IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
USE work.CMVD_DAQ_PKG.all;

Entity fifo2 IS
	PORT ( 
		    Clk          : in std_logic;
		    nReset	     : in std_logic;
		    WriteEnable  : in std_logic;
		    ReadEnable   : in std_logic;
		    DataIn       : in std_logic_vector(15 downto 0);
		    DataOut      : out std_logic_vector(15 downto 0);
		    FifoEmpty    : out std_logic;
		    FifoFull     : out std_logic;
			FreeSpace	  : out std_logic_vector(ADDR_width downto 0)      -- added Byte counter as freespace
	    );
END fifo2;

Architecture A_fifo2 of fifo2 IS

Type Mem is array ( FIFO_depth-1 downto 0) of std_logic_vector( 15 downto 0);
Signal Memory : Mem;

Signal ReadPointer  : std_logic_vector(ADDR_width-1 downto 0);
Signal WritePointer : std_logic_vector(ADDR_width-1 downto 0);
Signal ByteCounter  : std_logic_vector(ADDR_width downto 0);
signal wptrs        : std_logic_vector(ADDR_width-1 downto 0);
Signal FifoFull_s    : std_logic;
Signal FifoEmpty_s   : std_logic;

component ram_infer
	PORT
	(
		clock         : IN   std_logic;
		data          : IN   std_logic_vector (15 DOWNTO 0);
		write_address : IN   integer RANGE 0 to FIFO_depth-1;
		read_address  : IN   integer RANGE 0 to FIFO_depth-1;
		we            : IN   std_logic;
		re            : IN   std_logic;
		q             : OUT  std_logic_vector (15 DOWNTO 0)
	);
end component;

Begin

	ReadWriteFifoOut   : Process(Clk,nReset)
	variable wr_lock   : std_logic_vector (2 downto 0);
	variable rd_lock   : std_logic_vector (2 downto 0);
	Begin
		IF ( nReset = '0') then
			ReadPointer  <= (others => '0');
			WritePointer <= (others => '0');
			ByteCounter  <= (others => '0');
			wr_lock := (others => '0');
			rd_lock := (others => '0');
		ELSIF(Clk'event and Clk = '1') then
			IF ( WriteEnable = '0') then
				IF ( wr_lock < "010" ) then
					wr_lock := wr_lock + '1';
				END IF;
				IF ( wr_lock = "001") then
					IF ( FifoFull_s = '0' and ReadEnable = '1') then
						WritePointer <= WritePointer + 1;
						ByteCounter  <= ByteCounter + 1;
					END IF;
				END IF;
			ELSE
				wr_lock := "000";
			END IF;
			
			IF ( ReadEnable = '0') then
				IF ( rd_lock < "010" ) then
					rd_lock := rd_lock + '1';
				END IF;
				IF ( rd_lock = "001") then
					IF ( FifoEmpty_s = '0' and WriteEnable = '1') then
						ReadPointer  <= ReadPointer + 1;
						ByteCounter  <= ByteCounter - 1;
					END IF;
				END IF;
			ELSE
				rd_lock := "000";
			END IF;
				
		END IF;
	END process;-- ReadWriteFifo Process ends
	
-----------------------------------------------------------
--  Combinatorial Logic
-----------------------------------------------------------
	FifoEmpty_s <= '1' WHEN (ByteCounter = 0) else '0';
	FifoFull_s  <= ByteCounter(ADDR_width);
	FreeSpace   <=	ByteCounter;                --Copying Byte counter to freespace 
	FifoFull  <= FifoFull_s;
	FifoEmpty <= FifoEmpty_s;
	
------------------------------------------------------------
-- ram instantiation
------------------------------------------------------------
   ram0 : ram_infer
	PORT map
	(
		clock         => clk,
		data          => DataIn,
		write_address => Conv_Integer(WritePointer),
		read_address  => Conv_Integer(ReadPointer),
		we            => WriteEnable,
		re            => ReadEnable, ---  read enable 
		q             => DataOut
	);

END A_fifo2;
