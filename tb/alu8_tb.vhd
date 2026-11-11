-- alu8_tb.vhd : self-checking testbench for the ALU 
-- Checks all 8 operations, the carry/borrow flag and the zero flag.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity alu8_tb is
end entity alu8_tb;

architecture sim of alu8_tb is
  signal a, b  : std_logic_vector(7 downto 0) := (others => '0');
  signal op    : alu_op_t := ALU_ADD;
  signal y     : std_logic_vector(7 downto 0);
  signal carry : std_logic;
  signal zero  : std_logic;
begin
  dut : entity work.alu8
    port map (a => a, b => b, op => op, y => y, carry => carry, zero => zero);

  stim : process
    variable errors : natural := 0;
    variable tests  : natural := 0;

    -- Apply one test vector and compare all three outputs with what we expect
    procedure check (name   : string;
                     opcode : alu_op_t;
                     va, vb : natural;
                     exp_y  : natural;
                     exp_c  : std_logic;
                     exp_z  : std_logic) is
    begin
      a  <= std_logic_vector(to_unsigned(va, 8));
      b  <= std_logic_vector(to_unsigned(vb, 8));
      op <= opcode;
      wait for 10 ns;                       -- let the combinational logic settle
      tests := tests + 1;
      if to_integer(unsigned(y)) /= exp_y or carry /= exp_c or zero /= exp_z then
        errors := errors + 1;
        report name & ": a=" & integer'image(va) & " b=" & integer'image(vb) &
               "  got y=" & integer'image(to_integer(unsigned(y))) &
               " c=" & std_logic'image(carry) & " z=" & std_logic'image(zero) &
               "  expected y=" & integer'image(exp_y) &
               " c=" & std_logic'image(exp_c) & " z=" & std_logic'image(exp_z)
          severity error;
      end if;
    end procedure check;
  begin
    -- ADD: normal, carry out, result zero because of wrap-around
    check("ADD simple",   ALU_ADD, 10, 20, 30, '0', '0');
    check("ADD carry",    ALU_ADD, 200, 100, 44, '1', '0');       -- 300 - 256
    check("ADD wrap->0",  ALU_ADD, 255, 1, 0, '1', '1');
    check("ADD zero",     ALU_ADD, 0, 0, 0, '0', '1');
    -- SUB: normal, equal (zero), borrow
    check("SUB simple",   ALU_SUB, 9, 5, 4, '0', '0');
    check("SUB equal",    ALU_SUB, 5, 5, 0, '0', '1');
    check("SUB borrow",   ALU_SUB, 3, 5, 254, '1', '0');          -- 3-5 = -2 = 0xFE
    check("SUB 0-255",    ALU_SUB, 0, 255, 1, '1', '0');
    -- Logic operations (carry is always 0)
    check("AND",          ALU_AND, 16#3C#, 16#F0#, 16#30#, '0', '0');
    check("AND zero",     ALU_AND, 16#0F#, 16#F0#, 0, '0', '1');
    check("OR",           ALU_OR,  16#3C#, 16#F0#, 16#FC#, '0', '0');
    check("OR zero",      ALU_OR,  0, 0, 0, '0', '1');
    check("XOR",          ALU_XOR, 16#3C#, 16#F0#, 16#CC#, '0', '0');
    check("XOR same",     ALU_XOR, 77, 77, 0, '0', '1');
    -- Shifts: carry = bit that falls out
    check("SHL simple",   ALU_SHL, 16#81#, 0, 16#02#, '1', '0');
    check("SHL no carry", ALU_SHL, 16#01#, 0, 16#02#, '0', '0');
    check("SHL ->0",      ALU_SHL, 16#80#, 0, 0, '1', '1');
    check("SHR simple",   ALU_SHR, 16#81#, 0, 16#40#, '1', '0');
    check("SHR no carry", ALU_SHR, 16#02#, 0, 16#01#, '0', '0');
    check("SHR ->0",      ALU_SHR, 16#01#, 0, 0, '1', '1');
    -- PASS: result = b, a is ignored, carry 0
    check("PASS",         ALU_PASS, 99, 123, 123, '0', '0');
    check("PASS zero",    ALU_PASS, 99, 0, 0, '0', '1');

    if errors = 0 then
      report "ALU TB: ALL " & integer'image(tests) & " TESTS PASSED" severity note;
    else
      report "ALU TB: " & integer'image(errors) & " of " & integer'image(tests) & " TESTS FAILED"
        severity failure;
    end if;
    wait;
  end process;
end architecture sim;
