-- ram_tb.vhd : small testbench for the synchronous RAM 
-- 1) fresh RAM reads 0   2) write then read back   3) read-during-write returns the OLD value
-- 4) write/read all 256 addresses   5) we='0' must not change the memory
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ram_tb is
end entity ram_tb;

architecture sim of ram_tb is
  signal clk  : std_logic := '0';
  signal we   : std_logic := '0';
  signal addr : std_logic_vector(7 downto 0) := (others => '0');
  signal din  : std_logic_vector(7 downto 0) := (others => '0');
  signal dout : std_logic_vector(7 downto 0);
  signal done : boolean := false;
begin
  dut : entity work.data_ram
    port map (clk => clk, we => we, addr => addr, din => din, dout => dout);

  clk_gen : process
  begin
    while not done loop
      clk <= '0'; wait for 5 ns;
      clk <= '1'; wait for 5 ns;
    end loop;
    wait;
  end process;

  stim : process
    variable errors : natural := 0;

    procedure expect (name : string; exp : natural) is
    begin
      if to_integer(unsigned(dout)) /= exp then
        errors := errors + 1;
        report name & ": got " & integer'image(to_integer(unsigned(dout))) &
               ", expected " & integer'image(exp) severity error;
      end if;
    end procedure expect;

    -- One clock cycle: set inputs just after a rising edge, check outputs one cycle later
    procedure cycle (w : std_logic; a : natural; d : natural) is
    begin
      we   <= w;
      addr <= std_logic_vector(to_unsigned(a, 8));
      din  <= std_logic_vector(to_unsigned(d, 8));
      wait until rising_edge(clk);
      wait for 1 ns;                         -- dout has now been updated by that edge
    end procedure cycle;
  begin
    wait until rising_edge(clk);
    wait for 1 ns;

    cycle('0', 7, 0);   expect("fresh RAM reads 0", 0);
    cycle('1', 7, 99);  expect("write cycle returns OLD value", 0);   -- read-during-write
    cycle('0', 7, 0);   expect("read back after write", 99);
    cycle('1', 7, 55);  expect("overwrite returns OLD value", 99);
    cycle('0', 7, 0);   expect("read back overwrite", 55);
    cycle('0', 7, 11);  expect("we=0 does not write", 55);            -- din=11 is ignored
    cycle('0', 8, 0);   expect("neighbour untouched", 0);

    for i in 0 to 255 loop
      cycle('1', i, (i * 3 + 1) mod 256);
    end loop;
    for i in 0 to 255 loop
      cycle('0', i, 0);
      expect("sweep address " & integer'image(i), (i * 3 + 1) mod 256);
    end loop;

    if errors = 0 then
      report "RAM TB: ALL TESTS PASSED" severity note;
    else
      report "RAM TB: " & integer'image(errors) & " ERRORS" severity failure;
    end if;
    done <= true;
    wait;
  end process;
end architecture sim;
