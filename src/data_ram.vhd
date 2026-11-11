-- data_ram.vhd : 256 x 8 single-port RAM, synchronous write AND synchronous read
-- (this style lets Quartus map it onto an M9K memory block)
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity data_ram is
  port (
    clk  : in  std_logic;
    we   : in  std_logic;
    addr : in  std_logic_vector(7 downto 0);
    din  : in  std_logic_vector(7 downto 0);
    dout : out std_logic_vector(7 downto 0)
  );
end entity data_ram;

architecture rtl of data_ram is
  type ram_t is array (0 to 255) of std_logic_vector(7 downto 0);
  signal mem    : ram_t := (others => (others => '0'));
  signal dout_r : std_logic_vector(7 downto 0) := (others => '0');  -- read register (starts at 0, never 'U')
begin
  dout <= dout_r;

  process (clk)
  begin
    if rising_edge(clk) then
      if we = '1' then
        mem(to_integer(unsigned(addr))) <= din;
      end if;
      dout_r <= mem(to_integer(unsigned(addr)));   -- reads the OLD value when writing
    end if;
  end process;
end architecture rtl;
