-- cpu_tb.vhd : self-checking testbench.
-- Seven CPUs run in parallel, one per test program in prog_rom. A monitor per CPU
-- compares every OUT value with the expected list and counts the outputs.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cpu_tb is
end entity cpu_tb;

architecture sim of cpu_tb is
  constant CLK_PERIOD : time    := 10 ns;
  constant N_PROG     : natural := 7;

  type int_vec  is array (natural range <>) of integer;
  type int_mat  is array (natural range <>, natural range <>) of integer;
  type byte_arr is array (0 to N_PROG - 1) of std_logic_vector(7 downto 0);

  -- Expected OUT values per program (rows) and how many of them are valid
  constant EXP_COUNT : int_vec(0 to 6) := (1, 10, 1, 6, 4, 3, 1);
  constant EXP : int_mat(0 to 6, 0 to 9) := (
    (55,   0,   0,  0,   0, 0, 0,  0,  0,  0),   -- PROG0: 1+2+...+10
    (0,    1,   1,  2,   3, 5, 8, 13, 21, 34),   -- PROG1: Fibonacci
    (143,  0,   0,  0,   0, 0, 0,  0,  0,  0),   -- PROG2: 13 * 11
    (48, 252, 204,  4, 254, 2, 0,  0,  0,  0),   -- PROG3: 0x30 0xFC 0xCC 0x04 0xFE 0x02
    (7,    0, 255,  1,   0, 0, 0,  0,  0,  0),   -- PROG4: SUBI / JNC / STA+LDA back to back
    (12,  24,  28,  0,   0, 0, 0,  0,  0,  0),   -- PROG5: CALL / RET (4 levels deep)
    (12,   0,   0,  0,   0, 0, 0,  0,  0,  0));  

  constant ALL_HALTED : std_logic_vector(0 to N_PROG - 1) := (others => '1');
  constant NO_ERRORS  : std_logic_vector(0 to N_PROG - 1) := (others => '0');

  signal clk  : std_logic := '0';
  signal rst  : std_logic := '1';
  signal done : boolean   := false;

  signal out_port   : byte_arr;
  signal out_strobe : std_logic_vector(0 to N_PROG - 1);
  signal halted     : std_logic_vector(0 to N_PROG - 1);
  signal count      : int_vec(0 to N_PROG - 1) := (others => 0);
  signal err        : std_logic_vector(0 to N_PROG - 1) := (others => '0');
begin
  -- Clock generator (stops when the test is finished)
  clk_gen : process
  begin
    while not done loop
      clk <= '0';
      wait for CLK_PERIOD / 2;
      clk <= '1';
      wait for CLK_PERIOD / 2;
    end loop;
    wait;
  end process;

  -- One CPU + one monitor per test program
  gen : for i in 0 to N_PROG - 1 generate
    dut : entity work.cpu8
      generic map (PROG => i)
      port map (clk => clk, rst => rst,
                out_port => out_port(i), out_strobe => out_strobe(i), halted => halted(i));

    mon : process (clk)
      variable n : natural := 0;
    begin
      if rising_edge(clk) then
        if out_strobe(i) = '1' then
          assert n < EXP_COUNT(i)
            report "PROG " & integer'image(i) & ": unexpected extra output"
            severity failure;
          if to_integer(unsigned(out_port(i))) /= EXP(i, n) then
            err(i) <= '1';
            report "PROG " & integer'image(i) & " output " & integer'image(n) &
                   ": got " & integer'image(to_integer(unsigned(out_port(i)))) &
                   ", expected " & integer'image(EXP(i, n))
              severity error;
          end if;
          n := n + 1;
        end if;
        count(i) <= n;
      end if;
    end process;
  end generate;

  -- Reset, wait for all CPUs to halt, then check the results
  stim : process
    variable ok : boolean;
  begin
    rst <= '1';
    wait for 3 * CLK_PERIOD;
    rst <= '0';

    wait until halted = ALL_HALTED for 50 us;
    wait for 10 * CLK_PERIOD;

    ok := (halted = ALL_HALTED) and (err = NO_ERRORS);
    if halted /= ALL_HALTED then
      report "TIMEOUT: not every program reached HLT" severity error;
    end if;

    for i in 0 to N_PROG - 1 loop
      if count(i) /= EXP_COUNT(i) then
        ok := false;
        report "PROG " & integer'image(i) & ": expected " & integer'image(EXP_COUNT(i)) &
               " outputs, got " & integer'image(count(i))
          severity error;
      end if;
    end loop;

    if ok then
      report "ALL TESTS PASSED" severity note;
    else
      report "SOME TESTS FAILED" severity failure;
    end if;

    done <= true;
    wait;
  end process;
end architecture sim;
