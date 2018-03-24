
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
  port(CLOCK_50 : in  std_logic;  -- Clock pin
       KEY : in  std_logic_vector(3 downto 0);  -- push button switches
       SW : in  std_logic_vector(17 downto 0);  -- slider switches
		 LEDG : out std_logic_vector(7 downto 0);  -- green lights
		 LEDR : out std_logic_vector(17 downto 0);  -- red lights
		hex0 : out std_logic_vector(6 downto 0);
		hex1 : out std_logic_vector(6 downto 0);
		hex2 : out std_logic_vector(6 downto 0);
		hex3 : out std_logic_vector(6 downto 0);
		hex4 : out std_logic_vector(6 downto 0);
		hex5 : out std_logic_vector(6 downto 0);
			lcd_rw : out std_logic;
			lcd_en : out std_logic;
			lcd_rs : out std_logic;
			lcd_on : out std_logic;
			lcd_blon : out std_logic;
			lcd_data : out std_logic_vector(7 downto 0));
end ksa;

-- Architecture part of the description

architecture rtl of ksa is

   -- Declare the component for the ram.  This should match the entity description 
	-- in the entity created by the megawizard. If you followed the instructions in the 
	-- handout exactly, it should match.  If not, look at s_memory.vhd and make the
	-- changes to the component below
	
	COMPONENT s_memory IS
	PORT (
	   address		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
	   clock		: IN STD_LOGIC  := '1';
	   data		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
	   wren		: IN STD_LOGIC ;
	   q		: OUT STD_LOGIC_VECTOR (7 DOWNTO 0));
	END component;
	
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
	
	component digit7seg
		PORT(
				 digit : IN  UNSIGNED(3 DOWNTO 0);  -- number 0 to 0xF
				 seg7 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0)  -- one per segment
		);
	end component;

	component slowclock
		port(
			CLOCK_50: in std_logic;
			debounce_clk: out std_logic
		);
	end component;
	-- Enumerated type for the state variable.  You will likely be adding extra
	-- state names here as you complete your design
	-- appended # n: nth loop implementation of the RC4 algorithm
	type state_type is ( state_init, state_fill1, state_reset1, state_readi2a, state_readj2a, state_writei2, state_writej2, 
						 state_readi2b, state_readj2b, state_readf_and_encrypk2b, state_write_decrypk2b, state_done, state_empty
	);
							
    -- These are signals that are used to connect to the memory													 
	signal address : STD_LOGIC_VECTOR (7 DOWNTO 0);	 
	signal data : STD_LOGIC_VECTOR (7 DOWNTO 0);
	signal wren : STD_LOGIC;
	signal q : STD_LOGIC_VECTOR (7 DOWNTO 0);	

	signal address_d : STD_LOGIC_VECTOR (4 DOWNTO 0);	 
	signal data_d : STD_LOGIC_VECTOR (7 DOWNTO 0);
	signal wren_d : STD_LOGIC;
	signal q_d : STD_LOGIC_VECTOR (7 DOWNTO 0);	
	
	signal address_m : STD_LOGIC_VECTOR (4 DOWNTO 0);	
	signal q_m : STD_LOGIC_VECTOR (7 DOWNTO 0);	
	
	-- my code
	signal clk: std_logic;
	signal curr_state: state_type := state_type'left;
	signal next_state: state_type;		-- used to determine where to go next after a sleep cycle

	signal secret_key : hashKey;	-- begin search with all '0's and terminate at x"00FFFF"
	signal secret_keyUnsigned : unsigned(23 downto 0) := x"000000"; 	-- created for easy incrementing x"000000";
	
	signal found: std_logic := '0';
	
	signal clock_slow: std_logic;

	-- LCD ------------------------------------------
	signal EN_LCD : std_logic := '0';
		type statetype is (reset0, reset1, reset2, reset3, reset4, reset5,
							 state_write, state_clear, state_done, state_empty );	
		signal current_state: statetype := statetype'left;
		signal state_next: statetype;
		
		signal decrypted_msg : string32;
	-------------------------------------------------
		
	begin
		secret_key(2) <= secret_keyUnsigned(7 downto 0);
		secret_key(1) <= secret_keyUnsigned(15 downto 8);	
		secret_key(0) <= secret_keyUnsigned(23 downto 16);	-- kept at 0
		
		-- LCD
		l0: slowclock port map (CLOCK_50 => CLOCK_50, debounce_clk => clock_slow);
		
		-- Include the S memory structurally
		u0: s_memory port map (address, clk, data, wren, q);
		u1: d_memory port map (address_d, clk, data_d, wren_d, q_d);
		u2: r_memory port map (address_m, clk, q_m);
		
		-- Display secret_key
		hex0_block : digit7seg port map ( secret_key(0)(7 downto 4), hex0 );
		hex1_block : digit7seg port map ( secret_key(0)(3 downto 0), hex1 );
		hex2_block : digit7seg port map ( secret_key(1)(7 downto 4), hex2 );
		hex3_block : digit7seg port map ( secret_key(1)(3 downto 0), hex3 );
		hex4_block : digit7seg port map ( secret_key(2)(7 downto 4), hex4 );
		hex5_block : digit7seg port map ( secret_key(2)(3 downto 0), hex5 );
		
		clk <= CLOCK_50;
		
	process(clk)
		-- appended #: the task # in lab handout
		type state_type is ( state_init, state_fill1, state_reset1, state_readi2a, state_readj2a, state_writei2, state_writej2, 
							 state_readi2b, state_readj2b, state_readf_and_encrypk2b, state_write_decrypk2b, state_done, state_empty
		);
		variable curr_state: state_type := state_type'left;
		variable next_state: state_type;		-- used to determine where to go next after a sleep cycle
		
		-- i, i, s[i], s[j], f, encrypted_msg[k]
		variable i, j, tmp, tmp_si, tmp_sj, tmp_f, tmp_encrypk, tmp_decrypk : unsigned(7 downto 0) := (others => '0');
		variable k: unsigned(4 downto 0) := (others => '0');
		variable k_index: integer range 0 to 3 := 0;
		variable taskflg : std_logic := '0';		-- 0: we are in task 2a);	1: we in task 2b)
	begin
		if rising_edge(clk) then
			case curr_state is
				-- Task 1) First Loop in algorithm
				when state_init =>
					i := (others => '0');
					wren <= '1';
					address <= std_logic_vector(i);
					data <= std_logic_vector(i);
					curr_state := state_fill1;
				 
				when state_fill1 =>
					address <= std_logic_vector(i);
					data <= std_logic_vector(i);
					wren <= '1';
					
					if i < 255 then
						i := i + 1;
						curr_state := state_fill1;
					else 
						wren <= '1';
						address <= std_logic_vector(i);
						data <= std_logic_vector(i);
						curr_state := state_reset1;
					end if;
					
				when state_reset1=>
						-- clear i for re-use
						i := (others => '0');
						j := (others => '0');
						taskflg := '0';		-- about to enter task a)
					curr_state := state_readi2a;
					
				-- Task 2a) Second Loop in algorithm
				when state_readi2a =>
					-- add the two terms and wait for s[i]
					k_index := to_integer(i mod 3);
					tmp := j + unsigned(secret_key(k_index));
					-- read s[i]
					wren <= '0';    
					address <= std_logic_vector(i);
					
					curr_state := state_empty;
					next_state := state_readj2a;
					
				when state_readj2a =>
					-- catch s[i]
					tmp_si := unsigned(q);
					j := (tmp + tmp_si);
					-- read s[j] for swapping
					wren <= '0';
					address <= std_logic_vector(j);

					curr_state := state_empty;
					next_state := state_writei2;

				when state_writei2 =>
					-- catch s[j]
					tmp_sj := unsigned(q);
					-- write s[i] for swapping
					wren <= '1';
					address <= std_logic_vector(i);
					data <= std_logic_vector(tmp_sj);
					curr_state := state_writej2;
						
				when state_writej2 =>
					-- write s[j] for swapping
					wren <= '1';
					address <= std_logic_vector(j);
					data <= std_logic_vector(tmp_si);
					
					if taskflg = '0' then	-- swapping for task 2a)
						if i < 255 then
							i := i + 1;
							curr_state := state_readi2a;
						else 
							taskflg := '1';
							i := (others => '0');
							j := (others => '0');
							k := (others => '0');
							tmp_si := (others => '0');
							tmp_sj := (others => '0');
							tmp_f := (others => '0');
							tmp_encrypk := (others => '0');
							curr_state := state_readi2b;
						end if;
					elsif taskflg = '1' then	-- swapping for task 2b)
						curr_state := state_readf_and_encrypk2b;
					else	-- err state
						curr_state := state_done;
					end if;
						
						
				-- Task 2b) compute one byte per character in the encrypted message.
				when state_readi2b =>
					-- turn off write to output from (potential) last iteration 
					wren_d <= '0';
					--determine i
					i := i + 1;
					-- read s[i] for swapping
					wren <= '0';
					address <= std_logic_vector(i);
					curr_state := state_empty;
					next_state := state_readj2b;
				
				when state_readj2b =>
					-- catch s[i]
					tmp_si := unsigned(q);
					
					--determine j
					j := j + tmp_si;
					-- read s[j] for swapping
					wren <= '0';
					address <= std_logic_vector(j);
					curr_state := state_empty;
					next_state := state_writei2;	-- writei2 & writej2 from part 2a) performs swapping, exactly what we want. 
					-- we just need to feed a flag saying this is swapping for task2b). this is done in state_writej2 (currently line 181)
				
				when state_readf_and_encrypk2b =>
					-- read f = s[tmp_si + tmp_sj]
					wren <= '0';
					address <= std_logic_vector(tmp_si + tmp_sj);
					-- read encrypted_msg[k]: Now done from array
					address_m <= std_logic_vector(k);
					
					curr_state := state_empty;
					next_state := state_write_decrypk2b;
				
				when state_write_decrypk2b => 
					-- catch f = s[tmp_si + tmp_sj]
					tmp_f := unsigned(q);
					-- catch f = s[tmp_si + tmp_sj]
					tmp_encrypk := unsigned(q_m);
					
					tmp_decrypk := tmp_f xor tmp_encrypk;

					if (tmp_decrypk >= 97 and tmp_decrypk <= 122) or tmp_decrypk = 32 then
						-- write decrypted_output[k]
						wren_d <= '1';
						address_d <= std_logic_vector(k);
						data_d <= std_logic_vector(tmp_decrypk);
						
						decrypted_msg(to_integer(k)) <= tmp_decrypk;
						if k < 31 then
							k := k + 1;
							curr_state := state_readi2b;
						else 
							found <= '1';
							curr_state := state_done;
						end if;
					else
						-- update key
						if secret_keyUnsigned(22) = '1' then	-- out of bounds
							-- exhausted potential keys
							curr_state := state_done;
						else
							secret_keyUnsigned <= secret_keyUnsigned + 1;
							curr_state := state_init;
						end if;
					end if;
				
				when state_done =>
					wren <= '0';
					wren_d <= '0';
					LEDR(0) <= found;
					LEDR(16) <= '0';
					LEDR(17) <= '1';
					-- begin printing to LCD
					EN_LCD <= '1';
					curr_state := state_done;
					
				-- empty sleep cycle. Turns out you need this after a read is issued.
				when state_empty =>
					curr_state := next_state;
				
				when others =>
					wren <= '0';
					curr_state := state_done;
			end case;	 
		end if;
	end process;
		
	comb_process: process(clock_slow) 
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
			-- debug
			ledg <= "00000001";
		when reset1 =>	-- 00111000 x"38"
			lcd_data <= "00111000";
			lcd_rs <= '0';
			current_state <= reset2;
			-- debug
			ledg <= "00000010";
		when reset2 =>	-- 00001100 x"0C"
			lcd_data <= "00001100";
			lcd_rs <= '0';
			current_state <= reset3;
			-- debug
			ledg <= "00000011";
		when reset3 =>	-- 00000001 x"01"
			lcd_data <= "00000001";
			lcd_rs <= '0';
			current_state <= reset4;
			-- debug
			ledg <= "00000100";
		when reset4 =>	-- 00000110 x"06"
			lcd_data <= "00000110";
			lcd_rs <= '0';
			current_state <= reset5;
			-- debug
			ledg <= "00000101";
		when reset5 =>	-- 10000000 x"80"
			lcd_data <= "10000000";
			lcd_rs <= '0';
			current_state <= state_write;
			-- debug
			ledg <= "00000110";

		when state_write =>
		
			lcd_data <= std_logic_vector(decrypted_msg(to_integer(k)));
			lcd_rs <= '1';
			ledg <= "10000001";
			
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
			-- debug
			ledg <= "11111111";
			
		when state_done =>
			lcd_data <= "00000001";
			lcd_rs <= '0';
			current_state <= state_done;
			ledg(6) <= '1';
			
		when state_empty =>
			current_state <= state_next;
			
		when others =>
			current_state <= state_done;
			
		end case;
	end if;
	end process comb_process;
	
end RTL;


