-- alu8.vhd : combinational 8-bit ALU with carry/borrow and zero flags
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity alu8 is
  port (
    a     : in  std_logic_vector(7 downto 0);   -- first operand  (accumulator)
    b     : in  std_logic_vector(7 downto 0);   -- second operand (RAM data or immediate)
    op    : in  alu_op_t;                       -- operation select
    y     : out std_logic_vector(7 downto 0);   -- result
    carry : out std_logic;                      -- carry out (ADD), borrow (SUB), shifted-out bit (SHL/SHR)
    zero  : out std_logic                       -- '1' when the result is 0
  );
end entity alu8;

architecture rtl of alu8 is
begin
  process (a, b, op)
    variable ua, ub, r : unsigned(8 downto 0);  -- 9 bits: bit 8 is the carry/borrow
  begin
    ua := '0' & unsigned(a);
    ub := '0' & unsigned(b);
    r  := (others => '0');

    case op is
      when ALU_ADD  => r := ua + ub;
      when ALU_SUB  => r := ua - ub;                      -- bit 8 = 1 when a < b (borrow)
      when ALU_AND  => r := ua and ub;
      when ALU_OR   => r := ua or ub;
      when ALU_XOR  => r := ua xor ub;
      when ALU_SHL  => r := ua(7) & ua(6 downto 0) & '0';  -- carry = old bit 7
      when ALU_SHR  => r := ua(0) & '0' & ua(7 downto 1);  -- carry = old bit 0
      when ALU_PASS => r := ub;
      when others   => r := ub;
    end case;

    y     <= std_logic_vector(r(7 downto 0));
    carry <= r(8);
    if r(7 downto 0) = 0 then
      zero <= '1';
    else
      zero <= '0';
    end if;
  end process;
end architecture rtl;
