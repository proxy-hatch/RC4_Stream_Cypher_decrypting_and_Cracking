-- Filename: crack.vhd
-- Author 1: Sheung Yau (Gary) Chung
-- Author 1 Student #: 301236546
-- Author 2: Yu Xuan (Shawn) Wang
-- Author 2 Student #: 301227972
-- Group Number: 40
-- Lab Section: LA04
-- Lab: ASB 10808
-- Task Completed: 2, 3, Challenge
-- Date: March 9, 2018 
--
-- Note: 
-- this entity is designed to be instantiated 4 times, each covering 1/4 of the possible keys. Passing in 1-4 as their worker#.
-- Also, different from the popular budget drug, this is intended to be used to decrypt the RC4 stream cypher without a key with brute force 
------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Common.all;

entity crack is
	port(
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
end crack;


architecture rtl of crack is
	COMPONENT s_memory IS
	PORT (
	   address		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
	   clock		: IN STD_LOGIC  := '1';
	   data		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
	   wren		: IN STD_LOGIC ;
	   q		: OUT STD_LOGIC_VECTOR (7 DOWNTO 0));
	END component;
    -- Signals used to connect to the Working RAM
	signal address : STD_LOGIC_VECTOR (7 DOWNTO 0);	 
	signal data : STD_LOGIC_VECTOR (7 DOWNTO 0);
	signal wren : STD_LOGIC;
	signal q : STD_LOGIC_VECTOR (7 DOWNTO 0);	
	
	signal secret_keyUnsigned : unsigned(23 downto 0) := x"000000";--(others => '0'); 	-- created for easy incrementing
begin
	u0: s_memory port map (address, clk, data, wren, q);

	-- for the scope of this assignment bit 23 and 22 and kept at 0
	-- bit 21 and bit 20 determined by workerNum
	secret_keyUnsigned(21 downto 20) <= workerNum;
	
	secret_key(2) <= secret_keyUnsigned(7 downto 0);
	secret_key(1) <= secret_keyUnsigned(15 downto 8);	
	secret_key(0) <= secret_keyUnsigned(23 downto 16);

	-- total # of possible keys = secret_keyUnsigned(19 downto 0)
	
	process(clk, EN)
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
		if rising_edge(clk) and EN = '1' then
			
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
					-- address_m <= std_logic_vector(k);
					
					curr_state := state_empty;
					next_state := state_write_decrypk2b;
				
				when state_write_decrypk2b => 
					-- catch f = s[tmp_si + tmp_sj]
					tmp_f := unsigned(q);
					-- catch f = s[tmp_si + tmp_sj]
					tmp_encrypk := encrypted_msg(to_integer(k));
					
					tmp_decrypk := tmp_f xor tmp_encrypk;

					if (tmp_decrypk >= 97 and tmp_decrypk <= 122) or tmp_decrypk = 32 then
						-- write decrypted_output[k]
						decrypted_msg(to_integer(k)) <= tmp_decrypk;
						if k < 31 then
							k := k + 1;
							curr_state := state_readi2b;
						else 
							-- found key!
							found <= '1';
							curr_state := state_done;
						end if;
					else
						-- update key
						if secret_keyUnsigned(19 downto 0) = (19 downto 0 => '1') then
							-- exhausted potential keys
							curr_state := state_done;
						else
							secret_keyUnsigned(19 downto 0) <= secret_keyUnsigned(19 downto 0) + 1;
							curr_state := state_init;
						end if;
					end if;
				
				when state_done =>
					done <= '1';
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
		
		
		
end RTL;