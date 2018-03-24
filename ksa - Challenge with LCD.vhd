
-- Author 1: Sheung Yau (Gary) Chung
-- Author 1 Student #: 301236546
-- Author 2: Yu Xuan (Shawn) Wang
-- Author 2 Student #: 301227972
-- Group Number: 40
-- Lab Section: LA04
-- Lab: ASB 10808
-- Task Completed: 2a, 2b, 3, LCD, Challenge
-- Date: March 23, 2018 
------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Common.all;

-- Entity part of the description.  Describes inputs and outputs
entity ksa is
  generic(N: integer range 0 to 4 := 4); -- number of cores
  port(CLOCK_50 : in  std_logic;  -- Clock pin
		KEY : in  std_logic_vector(3 downto 0);  -- push button switches
		SW : in  std_logic_vector(17 downto 0);  -- slider switches
		LEDG : out std_logic_vector(3 downto 0);  -- green lights: to indicate which worker cracked the RC4
		LEDR : out std_logic_vector(17 downto 0);
		hex0 : out std_logic_vector(6 downto 0);
		hex1 : out std_logic_vector(6 downto 0);
		hex2 : out std_logic_vector(6 downto 0);
		hex3 : out std_logic_vector(6 downto 0);
		hex4 : out std_logic_vector(6 downto 0);
		hex5 : out std_logic_vector(6 downto 0);
		
		-- LCD
		lcd_rw : out std_logic;
		lcd_en : out std_logic;
		lcd_rs : out std_logic;
		lcd_on : out std_logic;
		lcd_blon : out std_logic;
		lcd_data : out std_logic_vector(7 downto 0)
	   );
end ksa;

-- Architecture part of the description

architecture rtl of ksa is
	-- The only memory accesses top level need is to read from ROM containing encrypted msg and write to output RAM
	component d_memory
		PORT
		(
			address		: IN STD_LOGIC_VECTOR (4 DOWNTO 0);
			clock		: IN STD_LOGIC  := '1';
			data		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
			wren		: IN STD_LOGIC ;
			q		: OUT STD_LOGIC_VECTOR (7 DOWNTO 0)
		);
		
	end component;
	component r_memory
		PORT
		(
			address		: IN STD_LOGIC_VECTOR (4 DOWNTO 0);
			clock		: IN STD_LOGIC  := '1';
			q		: OUT STD_LOGIC_VECTOR (7 DOWNTO 0)
		);
	end component;
	
	component crack
		port
		(
			clk : in  std_logic;  -- Clock pin
			workerNum : in unsigned(1 downto 0);	-- 1 out of 4 worker covering 1/4 of the search zone
			EN : in std_logic;
			-- the encrypted msg
			encrypted_msg : in string32;
			
			done : out std_logic := '0';
			found : out STD_LOGIC := '0';
			decrypted_msg : out string32;
			secret_key : out hashKey
		);
	end component;
	
	component digit7seg
	PORT(
          digit : IN  UNSIGNED(3 DOWNTO 0);  -- number 0 to 0xF
          seg7 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0)  -- one per segment
	);
	end component;
	
	signal clk: std_logic;

    -- Signals used to connect to the Decrypted Msg RAM
	signal address_d : STD_LOGIC_VECTOR (4 DOWNTO 0);	 
	signal data_d : STD_LOGIC_VECTOR (7 DOWNTO 0);
	signal wren_d : STD_LOGIC;
	signal q_d : STD_LOGIC_VECTOR (7 DOWNTO 0);	
    -- Signals used to connect to the Encrypted Msg ROM
	signal address_m : STD_LOGIC_VECTOR (4 DOWNTO 0);	
	signal q_m : STD_LOGIC_VECTOR (7 DOWNTO 0);	
	
	-- states
	type state_type is ( state_readROM_init, state_readROM, state_waitCrackDelivery, state_writeDecrypted, state_done, state_empty );
	signal curr_state : state_type := state_type'left;
	signal next_state : state_type;		-- used to determine where to go next after a sleep cycle
	
	signal encrypted_msg : string32;	-- 32 byte string
	signal EN_crack : std_logic_vector(N-1 downto 0) := (others => '0');	-- used to tell the crack workers that encrypted_msg is filled and ready to go!
	type msgs4 is array (0 to N-1) of string32;
	signal decrypted_msgs : msgs4;
	type haskKeys4 is array (0 to N-1) of hashKey;
	signal keys : haskKeys4;
	signal correctKey : hashKey;	-- reported by the winner worker
	
	signal cracked, finished : std_logic_vector(N-1 downto 0) := (others => '0');	-- used by workers to report found and done
	signal winner : integer range 0 to N-1;

	signal ledrMask : std_logic_vector(17 downto 0) := (others => '0');
	
	-- LCD ------------------------------------------
	signal EN_LCD : std_logic := '0';
		type statetype is (reset0, reset1, reset2, reset3, reset4, reset5,
							 state_write, state_clear, state_done, state_empty );	
		signal current_state: statetype := statetype'left;
		signal state_next: statetype;
	
	component slowclock
		port(
			CLOCK_50: in std_logic;
			debounce_clk: out std_logic
		);
	end component;
	signal clock_slow: std_logic;

	-------------------------------------------------
	begin
		ledr <= ledrMask;
		-- Include the S memory structurally
		u1: d_memory port map (address_d, clk, data_d, wren_d, q_d);	-- ROM for output
		u2: r_memory port map (address_m, clk, q_m);		-- ROM for encrypted_msg

		GEN_CRACKERS : for I in 0 to N-1 generate
			CRACKERS : crack port map
				( clk, to_unsigned(I,2), EN_crack(I), encrypted_msg, finished(I), cracked(I), decrypted_msgs(I), keys(I) );
		end generate GEN_CRACKERS;
		hex0_block : digit7seg port map ( correctKey(0)(7 downto 4), hex0 );
		hex1_block : digit7seg port map ( correctKey(0)(3 downto 0), hex1 );
		hex2_block : digit7seg port map ( correctKey(1)(7 downto 4), hex2 );
		hex3_block : digit7seg port map ( correctKey(1)(3 downto 0), hex3 );
		hex4_block : digit7seg port map ( correctKey(2)(7 downto 4), hex4 );
		hex5_block : digit7seg port map ( correctKey(2)(3 downto 0), hex5 );
	   
		-- LCD
		L0 : slowclock port map (CLOCK_50 => CLOCK_50, debounce_clk => clock_slow);
		
		clk <= CLOCK_50;
		ledrMask(N-1 downto 0) <= not(finished);
		LEDG(N-1 downto 0) <= cracked;
		
		process (clk)
			variable i : unsigned(4 downto 0) := (others => '0');
		begin
			if rising_edge(clk) then
				case curr_state is
					-- read encrypted_msg[0-31] from ROM
					when state_readROM_init =>
						ledrMask(15) <= '1';
						address_m <= std_logic_vector(i);
						curr_state <= state_empty;
						next_state <= state_readROM;
						
					when state_readROM =>
						encrypted_msg(to_integer(i)) <= unsigned(q_m);
						
						if i < 31 then
							i := i + 1;
							curr_state <= state_readROM_init;
						else
							EN_crack <= (others => '1');
							-- reset i for re-use
							i := (others =>'0');
							curr_state <= state_waitCrackDelivery;
						end if;
					
					-- wait for the delivery of good news from any crack worker
					when state_waitCrackDelivery =>
						ledrMask(15) <= '0';
						ledrMask(14) <= '1';
						if cracked /= "0000" then	-- at least one reported cracked and done
							-- find the one that found it
							for I in 0 to N-1 loop
								if cracked(I) = '1' then
									winner <= I;
									ledrMask(10) <= '1';
								end if;
							end loop;
							i := (others =>'0');
							curr_state <= state_writeDecrypted;
						elsif finished = "1111" then
							-- none found
							ledrMask(11) <= '1';
							curr_state <= state_done;
						else
							curr_state <= state_waitCrackDelivery;
						end if;
					
					when state_writeDecrypted =>
						ledrMask(14) <= '0';
						ledrMask(13) <= '1';

						-- hex display
						correctKey <= keys(winner);
						-- LCD display
						EN_crack <= cracked;	-- disable workers that did not deliver crack

						-- write decrypted_output[k]
						wren_d <= '1';
						address_d <= std_logic_vector(i);
						data_d <= std_logic_vector(decrypted_msgs(winner)(to_integer(i)));
						
						if i < 31 then
							i := i + 1;
							curr_state <= state_writeDecrypted;
						else 
							curr_state <= state_done;
						end if;
						
					when state_done =>
						ledrMask(17) <= '1';
						--ledrMask(16 downto 4) <= (others => '0');
						wren_d <= '0';
						
						-- begin printing to LCD
						EN_LCD <= '1';
						curr_state <= state_done;
					
					-- empty sleep cycle. Turns out you need this after a read is issued.
					when state_empty =>
						curr_state <= next_state;
						
					when others =>
						curr_state <= state_done;
				
				end case;
			end if;
		end process;
		
	-- LCD process --------------------------------------------------------
		
	LCD_process: process(clock_slow) 
		variable k: unsigned(4 downto 0) := (others => '0');
	begin
	  -- These will not change
	lcd_blon <= '1';
	lcd_on <= '1';
	lcd_rw <= '0';
	lcd_en <= clock_slow;

	if falling_edge(clock_slow) and EN_LCD = '1' then
		case current_state is 							-- depending upon the current state
												-- set output signals and next state
		-- Set up the LCD
		when reset0 =>	-- 00111000 x"38"
			lcd_data <= "00111000";
			lcd_rs <= '0';
			current_state <= reset1;

		when reset1 =>	-- 00111000 x"38"
			lcd_data <= "00111000";
			lcd_rs <= '0';
			current_state <= reset2;

		when reset2 =>	-- 00001100 x"0C"
			lcd_data <= "00001100";
			lcd_rs <= '0';
			current_state <= reset3;

		when reset3 =>	-- 00000001 x"01"
			lcd_data <= "00000001";
			lcd_rs <= '0';
			current_state <= reset4;

		when reset4 =>	-- 00000110 x"06"
			lcd_data <= "00000110";
			lcd_rs <= '0';
			current_state <= reset5;

		when reset5 =>	-- 10000000 x"80"
			lcd_data <= "10000000";
			lcd_rs <= '0';
			current_state <= state_write;

		when state_write =>
		
			lcd_data <= std_logic_vector(decrypted_msgs(winner)(to_integer(k)));
			lcd_rs <= '1';
			
			if k < 31 then
				if k = 15 then	-- approached EoL
					current_state <= state_clear;
				else
					current_state <= state_write;
				end if;
				k := k + 1;
			else 
				current_state <= state_done;
			end if;
		
		when state_clear =>
			lcd_data <= "00000001";
			lcd_rs <= '0';
			current_state <= state_write;

		when state_done =>
			lcd_data <= "00000001";
			lcd_rs <= '0';
			current_state <= state_done;
			
		when state_empty =>
			current_state <= state_next;
			
		when others =>
			current_state <= state_done;
			
		end case;
	end if;
	end process LCD_process;
	-------------------------------------------------------------------

end RTL;


