-- cpu_pkg.vhd : shared constants (opcodes, ALU codes) and a tiny assembler function
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package cpu_pkg is
  -- Instruction word (16 bits):  [15:11] opcode | [10:8] unused | [7:0] operand
  subtype opcode_t is std_logic_vector(4 downto 0);
  subtype alu_op_t is std_logic_vector(2 downto 0);

  -- Opcodes 
  constant OP_NOP  : opcode_t := "00000";  -- do nothing
  constant OP_LDI  : opcode_t := "00001";  -- ACC <= imm
  constant OP_LDA  : opcode_t := "00010";  -- ACC <= RAM[addr]
  constant OP_STA  : opcode_t := "00011";  -- RAM[addr] <= ACC
  constant OP_ADD  : opcode_t := "00100";  -- ACC <= ACC + RAM[addr]
  constant OP_ADDI : opcode_t := "00101";  -- ACC <= ACC + imm
  constant OP_SUB  : opcode_t := "00110";  -- ACC <= ACC - RAM[addr]
  constant OP_AND  : opcode_t := "00111";  -- ACC <= ACC and RAM[addr]
  constant OP_OR   : opcode_t := "01000";  -- ACC <= ACC or  RAM[addr]
  constant OP_XOR  : opcode_t := "01001";  -- ACC <= ACC xor RAM[addr]
  constant OP_SHL  : opcode_t := "01010";  -- ACC <= ACC << 1, C <= old bit 7
  constant OP_SHR  : opcode_t := "01011";  -- ACC <= ACC >> 1, C <= old bit 0
  constant OP_JMP  : opcode_t := "01100";  -- PC <= addr
  constant OP_JZ   : opcode_t := "01101";  -- if Z = 1 then PC <= addr
  constant OP_JNZ  : opcode_t := "01110";  -- if Z = 0 then PC <= addr
  constant OP_JC   : opcode_t := "01111";  -- if C = 1 then PC <= addr
  constant OP_LDC  : opcode_t := "10000";  -- CNT <= imm            (loop counter)
  constant OP_LOOP : opcode_t := "10001";  -- CNT <= CNT-1; if CNT-1 /= 0 then PC <= addr
  constant OP_OUT  : opcode_t := "10010";  -- OUT port <= ACC (one-cycle strobe)
  constant OP_SUBI : opcode_t := "10011";  -- ACC <= ACC - imm        (new)
  constant OP_JNC  : opcode_t := "10100";  -- if C = 0 then PC <= addr (new)
  constant OP_CALL : opcode_t := "10101";  -- push return address, PC <= addr (new)
  constant OP_RET  : opcode_t := "10110";  -- PC <= popped return address     (new)
  constant OP_HLT  : opcode_t := "11111";  -- stop the CPU

  -- ALU operation codes 
  constant ALU_ADD  : alu_op_t := "000";
  constant ALU_SUB  : alu_op_t := "001";
  constant ALU_AND  : alu_op_t := "010";
  constant ALU_OR   : alu_op_t := "011";
  constant ALU_XOR  : alu_op_t := "100";
  constant ALU_SHL  : alu_op_t := "101";
  constant ALU_SHR  : alu_op_t := "110";
  constant ALU_PASS : alu_op_t := "111";   -- y <= b (used by LDI / LDA)

  -- Builds one instruction word, e.g. instr(OP_LDI, 10)
  function instr(op : opcode_t; operand : natural) return std_logic_vector;
end package cpu_pkg;

package body cpu_pkg is
  function instr(op : opcode_t; operand : natural) return std_logic_vector is
    variable w : std_logic_vector(15 downto 0);
  begin
    w := op & "000" & std_logic_vector(to_unsigned(operand, 8));
    return w;
  end function instr;
end package body cpu_pkg;
