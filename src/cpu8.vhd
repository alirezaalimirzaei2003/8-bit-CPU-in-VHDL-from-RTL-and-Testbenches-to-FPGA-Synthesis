-- cpu8.vhd : 8-bit accumulator CPU 
--
-- Every instruction takes 2 clock cycles:
--   S_FETCH : IR <= ROM[PC], PC <= PC + 1, and RAM[operand] is read ahead
--   S_EXEC  : decode IR, run the ALU / update registers / write RAM
-- S_HALT is entered by HLT and left only by reset.
-- CALL/RET use a 4-level hardware return-address stack (circular, 2-bit stack pointer).
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity cpu8 is
  generic (PROG : natural := 0);               -- which test program the ROM holds
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;                -- synchronous, active high
    out_port   : out std_logic_vector(7 downto 0);
    out_strobe : out std_logic;                -- 1 clock cycle wide when OUT executes
    halted     : out std_logic                 -- '1' after HLT
  );
end entity cpu8;

architecture rtl of cpu8 is
  type state_t is (S_FETCH, S_EXEC, S_HALT);
  signal state : state_t := S_FETCH;

  -- Programmer-visible registers
  signal pc        : unsigned(7 downto 0)          := (others => '0');
  signal ir        : std_logic_vector(15 downto 0) := (others => '0');
  signal acc       : unsigned(7 downto 0)          := (others => '0');
  signal cnt       : unsigned(7 downto 0)          := (others => '0');  -- loop counter
  signal flag_z    : std_logic := '0';
  signal flag_c    : std_logic := '0';
  -- Return-address stack for CALL / RET (4 levels)
  type stack_t is array (0 to 3) of unsigned(7 downto 0);
  signal stack     : stack_t := (others => (others => '0'));
  signal sp        : unsigned(1 downto 0) := (others => '0');   -- points to the NEXT free slot
  signal out_reg   : std_logic_vector(7 downto 0)  := (others => '0');
  signal out_pulse : std_logic := '0';

  -- Fields of the instruction register
  signal opcode  : opcode_t                      := (others => '0');
  signal operand : std_logic_vector(7 downto 0) := (others => '0');

  -- Memory interconnect
  signal rom_data : std_logic_vector(15 downto 0) := (others => '0');
  signal ram_addr : std_logic_vector(7 downto 0)  := (others => '0');
  signal ram_dout : std_logic_vector(7 downto 0)  := (others => '0');
  signal ram_we   : std_logic                     := '0';

  -- ALU interconnect
  signal alu_b  : std_logic_vector(7 downto 0) := (others => '0');
  signal alu_op : alu_op_t                     := ALU_ADD;
  signal alu_y  : std_logic_vector(7 downto 0) := (others => '0');
  signal alu_c  : std_logic := '0';
  signal alu_z  : std_logic := '0';
begin
  
  -- Instruction decode (just wires)
  
  opcode  <= ir(15 downto 11);
  operand <= ir(7 downto 0);

  
  -- Sub-blocks
  
  u_rom : entity work.prog_rom
    generic map (PROG => PROG)
    port map (addr => std_logic_vector(pc), data => rom_data);

  u_ram : entity work.data_ram
    port map (clk => clk, we => ram_we, addr => ram_addr,
              din => std_logic_vector(acc), dout => ram_dout);

  u_alu : entity work.alu8
    port map (a => std_logic_vector(acc), b => alu_b, op => alu_op,
              y => alu_y, carry => alu_c, zero => alu_z);

  
  -- Control signals (combinational)
  
  -- During FETCH the RAM address comes straight from the instruction being
  -- fetched, so the (synchronous) RAM has its data ready when EXEC starts.
  -- During EXEC the address comes from IR (needed for STA).
  ram_addr <= rom_data(7 downto 0) when state = S_FETCH else operand;

  ram_we <= '1' when (state = S_EXEC and opcode = OP_STA) else '0';

  -- ALU second operand: immediate for LDI/ADDI/SUBI, RAM data for everything else
  alu_b <= operand when (opcode = OP_LDI or opcode = OP_ADDI or opcode = OP_SUBI) else ram_dout;

  with opcode select
    alu_op <= ALU_PASS when OP_LDI | OP_LDA,
              ALU_ADD  when OP_ADD | OP_ADDI,
              ALU_SUB  when OP_SUB | OP_SUBI,
              ALU_AND  when OP_AND,
              ALU_OR   when OP_OR,
              ALU_XOR  when OP_XOR,
              ALU_SHL  when OP_SHL,
              ALU_SHR  when OP_SHR,
              ALU_ADD  when others;

  out_port   <= out_reg;
  out_strobe <= out_pulse;
  halted     <= '1' when state = S_HALT else '0';

  
  -- Registers + FSM (one clocked process)
  
  process (clk)
  begin
    if rising_edge(clk) then
      out_pulse <= '0';                          -- default: strobe is only 1 cycle wide

      if rst = '1' then
        state   <= S_FETCH;
        pc      <= (others => '0');
        ir      <= (others => '0');
        acc     <= (others => '0');
        cnt     <= (others => '0');
        sp      <= (others => '0');
        flag_z  <= '0';
        flag_c  <= '0';
        out_reg <= (others => '0');
      else
        case state is

          when S_FETCH =>
            ir    <= rom_data;
            pc    <= pc + 1;
            state <= S_EXEC;

          when S_EXEC =>
            state <= S_FETCH;                    -- default: go fetch the next one
            case opcode is
              -- Instructions that use the ALU: write ACC and both flags
              when OP_LDI | OP_LDA | OP_ADD | OP_ADDI | OP_SUB | OP_SUBI |
                   OP_AND | OP_OR  | OP_XOR | OP_SHL  | OP_SHR =>
                acc    <= unsigned(alu_y);
                flag_z <= alu_z;
                flag_c <= alu_c;

              when OP_STA =>
                null;                            -- RAM write is done by ram_we

              when OP_JMP =>
                pc <= unsigned(operand);

              when OP_JZ =>
                if flag_z = '1' then
                  pc <= unsigned(operand);
                end if;

              when OP_JNZ =>
                if flag_z = '0' then
                  pc <= unsigned(operand);
                end if;

              when OP_JC =>
                if flag_c = '1' then
                  pc <= unsigned(operand);
                end if;

              when OP_JNC =>
                if flag_c = '0' then
                  pc <= unsigned(operand);
                end if;

              when OP_CALL =>
                stack(to_integer(sp)) <= pc;     -- pc already points to the NEXT instruction
                sp <= sp + 1;
                pc <= unsigned(operand);

              when OP_RET =>
                pc <= stack(to_integer(sp - 1)); -- newest return address
                sp <= sp - 1;

              when OP_LDC =>
                cnt <= unsigned(operand);

              when OP_LOOP =>
                cnt <= cnt - 1;
                if cnt /= 1 then                 -- i.e. (cnt - 1) /= 0
                  pc <= unsigned(operand);
                end if;

              when OP_OUT =>
                out_reg   <= std_logic_vector(acc);
                out_pulse <= '1';

              when OP_HLT =>
                state <= S_HALT;

              when others =>                     -- NOP and unknown opcodes
                null;
            end case;

          when S_HALT =>
            null;                                -- stay here until reset
        end case;
      end if;
    end if;
  end process;
end architecture rtl;
