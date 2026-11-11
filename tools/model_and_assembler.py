# Golden model + mini assembler for the 8-bit accumulator CPU.
# Run:  python model_and_assembler.py          -> checks that every test program prints the expected OUT values
#       python model_and_assembler.py --gen    -> ALSO regenerates ../src/prog_rom.vhd from the programs below
import sys
OPS = dict(NOP=0b00000, LDI=0b00001, LDA=0b00010, STA=0b00011, ADD=0b00100, ADDI=0b00101,
           SUB=0b00110, AND=0b00111, OR=0b01000, XOR=0b01001, SHL=0b01010, SHR=0b01011,
           JMP=0b01100, JZ=0b01101, JNZ=0b01110, JC=0b01111, LDC=0b10000, LOOP=0b10001,
           OUT=0b10010, SUBI=0b10011, JNC=0b10100, CALL=0b10101, RET=0b10110, HLT=0b11111)
NOARG = {"NOP", "SHL", "SHR", "OUT", "RET", "HLT"}

# (label, mnemonic, operand, comment)  -- operand may be a number or a label name
P0 = [  # sum 1..10 = 55
 (None,"LDI",0,"sum = 0"), (None,"STA",0,"RAM[0] = sum"),
 (None,"LDI",1,"i = 1"),   (None,"STA",1,"RAM[1] = i"),
 (None,"LDC",10,"loop counter = 10"),
 ("loop","LDA",0,"ACC = sum"), (None,"ADD",1,"ACC = sum + i"), (None,"STA",0,"sum = ACC"),
 (None,"LDA",1,"ACC = i"), (None,"ADDI",1,"ACC = i + 1"), (None,"STA",1,"i = ACC"),
 (None,"LOOP","loop","C = C - 1, repeat while C /= 0"),
 (None,"LDA",0,"ACC = sum"), (None,"OUT",None,"output 55"), (None,"HLT",None,"stop")]
P1 = [  # first 10 Fibonacci numbers
 (None,"LDI",0,"a = 0"), (None,"STA",0,"RAM[0] = a"),
 (None,"LDI",1,"b = 1"), (None,"STA",1,"RAM[1] = b"),
 (None,"LDC",10,"10 numbers"),
 ("loop","LDA",0,"ACC = a"), (None,"OUT",None,"output a"),
 (None,"ADD",1,"ACC = a + b"), (None,"STA",2,"tmp = a + b"),
 (None,"LDA",1,"ACC = b"), (None,"STA",0,"a = b"),
 (None,"LDA",2,"ACC = tmp"), (None,"STA",1,"b = tmp"),
 (None,"LOOP","loop","next number"), (None,"HLT",None,"stop")]
P2 = [  # shift-and-add multiply 13 * 11 = 143
 (None,"LDI",13,"multiplicand M"), (None,"STA",0,"RAM[0] = M"),
 (None,"LDI",11,"multiplier Q"),   (None,"STA",1,"RAM[1] = Q"),
 (None,"LDI",0,"product P = 0"),   (None,"STA",2,"RAM[2] = P"),
 (None,"LDC",8,"8 bits"),
 ("loop","LDA",1,"ACC = Q"), (None,"SHR",None,"Q >> 1, carry = old bit 0"),
 (None,"STA",1,"Q = Q >> 1 (STA keeps the flags)"),
 (None,"JC","addp","bit was 1 -> add"), (None,"JMP","shiftm","bit was 0 -> skip add"),
 ("addp","LDA",2,"ACC = P"), (None,"ADD",0,"ACC = P + M"), (None,"STA",2,"P = ACC"),
 ("shiftm","LDA",0,"ACC = M"), (None,"SHL",None,"M << 1"), (None,"STA",0,"M = ACC"),
 (None,"LOOP","loop","next bit"),
 (None,"LDA",2,"ACC = P"), (None,"OUT",None,"output 143"), (None,"HLT",None,"stop")]
P3 = [  # ALU / flag / jump self-test
 (None,"LDI",0xF0,"mask"), (None,"STA",0,"RAM[0] = 0xF0"),
 (None,"LDI",5,"five"), (None,"STA",1,"RAM[1] = 5"),
 (None,"LDI",0x3C,""), (None,"AND",0,"0x3C & 0xF0 = 0x30"), (None,"OUT",None,"expect 0x30"),
 (None,"LDI",0x3C,""), (None,"OR",0,"0x3C | 0xF0 = 0xFC"), (None,"OUT",None,"expect 0xFC"),
 (None,"LDI",0x3C,""), (None,"XOR",0,"0x3C ^ 0xF0 = 0xCC"), (None,"OUT",None,"expect 0xCC"),
 (None,"LDI",9,""), (None,"SUB",1,"9 - 5 = 4"), (None,"OUT",None,"expect 0x04"),
 (None,"LDI",5,""), (None,"SUB",1,"5 - 5 = 0, Z = 1"), (None,"JZ","zok","must jump"),
 (None,"LDI",0xEE,"skipped"), (None,"OUT",None,"skipped"),
 ("zok","LDI",3,""), (None,"SUB",1,"3 - 5 = 0xFE, borrow -> C = 1"), (None,"JC","cok","must jump"),
 (None,"LDI",0xEE,"skipped"), (None,"OUT",None,"skipped"),
 ("cok","OUT",None,"expect 0xFE"),
 (None,"LDI",0x81,""), (None,"SHL",None,"0x02, C = 1"), (None,"JNZ","nzok","must jump"),
 (None,"LDI",0xEE,"skipped"), (None,"OUT",None,"skipped"),
 ("nzok","OUT",None,"expect 0x02"), (None,"HLT",None,"stop")]
P4 = [  # SUBI / JNC / back-to-back STA+LDA
 (None,"LDI",10,""), (None,"SUBI",3,"10 - 3 = 7"), (None,"OUT",None,"expect 7"),
 (None,"SUBI",7,"7 - 7 = 0, Z = 1, C = 0"), (None,"JNC","ncok","C = 0 -> must jump"),
 (None,"LDI",0xEE,"skipped"), (None,"OUT",None,"skipped"),
 ("ncok","OUT",None,"expect 0"),
 (None,"SUBI",1,"0 - 1 = 0xFF, borrow -> C = 1"), (None,"JNC","bad","C = 1 -> must NOT jump"),
 (None,"OUT",None,"expect 255"), (None,"JMP","b2b","continue"),
 ("bad","LDI",0xEE,"error path"), (None,"OUT",None,"error path"),
 ("b2b","STA",5,"RAM[5] = 255"), (None,"LDA",5,"read the SAME address right after the write"),
 (None,"ADDI",2,"255 + 2 = 1, C = 1"), (None,"OUT",None,"expect 1"), (None,"HLT",None,"stop")]
P5 = [  # CALL / RET, nested 4 levels deep
 (None,"LDI",3,"ACC = 3"), (None,"CALL","quad",""), (None,"OUT",None,"expect 12"),
 (None,"CALL","double","12 -> 24"), (None,"OUT",None,"expect 24"),
 (None,"CALL","lvl1","4 nested levels: +4"), (None,"OUT",None,"expect 28"), (None,"HLT",None,"stop"),
 ("quad","CALL","double","x2"), (None,"CALL","double","x2 again"), (None,"RET",None,""),
 ("double","STA",0,"tmp = ACC"), (None,"ADD",0,"ACC = ACC + tmp"), (None,"RET",None,""),
 ("lvl1","ADDI",1,""), (None,"CALL","lvl2",""), (None,"RET",None,""),
 ("lvl2","ADDI",1,""), (None,"CALL","lvl3",""), (None,"RET",None,""),
 ("lvl3","ADDI",1,""), (None,"CALL","lvl4",""), (None,"RET",None,""),
 ("lvl4","ADDI",1,""), (None,"RET",None,"")]
P6 = [  # the 5-instruction demo for the waveform 
 (None,"LDI",7,"ACC = 7"), (None,"ADDI",5,"ACC = 12"), (None,"STA",9,"RAM[9] = 12"),
 (None,"OUT",None,"output 12"), (None,"HLT",None,"stop")]
PROGS = [P0, P1, P2, P3, P4, P5, P6]
EXPECT = [[55], [0,1,1,2,3,5,8,13,21,34], [143], [0x30,0xFC,0xCC,4,0xFE,2], [7,0,255,1], [12,24,28], [12]]

def assemble(p):
    labels, a = {}, 0
    for lab, *_ in p:
        if lab: labels[lab] = a
        a += 1
    words = []
    for lab, m, x, c in p:
        v = labels[x] if isinstance(x, str) else (0 if x is None else x)
        words.append((m, v, c, lab))
    return words

def run(words, maxcyc=100000):
    pc = acc = cnt = 0; z = cy = 0; ram = [0]*256; out = []; cyc = 0; instrs = 0
    stack = [0]*4; sp = 0   # 4-level circular return-address stack
    while cyc < maxcyc:
        m, v, _, _ = words[pc] if pc < len(words) else ("HLT", 0, "", None)
        pc = (pc + 1) & 255; cyc += 2; instrs += 1
        def setf(r, c): 
            nonlocal acc, z, cy
            acc = r & 255; z = int(acc == 0); cy = c
        if m == "LDI": setf(v, 0)
        elif m == "LDA": setf(ram[v], 0)
        elif m == "STA": ram[v] = acc
        elif m == "ADD": r = acc + ram[v]; setf(r, r >> 8)
        elif m == "ADDI": r = acc + v; setf(r, r >> 8)
        elif m == "SUB": r = acc - ram[v]; setf(r & 255, int(r < 0))
        elif m == "SUBI": r = acc - v; setf(r & 255, int(r < 0))
        elif m == "AND": setf(acc & ram[v], 0)
        elif m == "OR": setf(acc | ram[v], 0)
        elif m == "XOR": setf(acc ^ ram[v], 0)
        elif m == "SHL": setf((acc << 1) & 255, acc >> 7)
        elif m == "SHR": setf(acc >> 1, acc & 1)
        elif m == "JMP": pc = v
        elif m == "JZ":  pc = v if z else pc
        elif m == "JNZ": pc = v if not z else pc
        elif m == "JC":  pc = v if cy else pc
        elif m == "JNC": pc = v if not cy else pc
        elif m == "CALL": stack[sp] = pc; sp = (sp + 1) & 3; pc = v
        elif m == "RET": sp = (sp - 1) & 3; pc = stack[sp]
        elif m == "LDC": cnt = v
        elif m == "LOOP":
            old = cnt; cnt = (cnt - 1) & 255
            if old != 1: pc = v
        elif m == "OUT": out.append(acc)
        elif m == "HLT": break
    return out, cyc, instrs

def gen_rom(allok):
    """Write ../src/prog_rom.vhd. Refuses to do it if the golden model fails."""
    if not allok:
        sys.exit("model failed - prog_rom.vhd NOT written")
    head = """-- prog_rom.vhd : program memory (256 x 16-bit words, asynchronous read)
-- GENERATED by tools/model_and_assembler.py --gen  (edit the Python programs, not this file)
-- The generic PROG selects which test program is stored in the ROM.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity prog_rom is
  generic (PROG : natural := 0);
  port (
    addr : in  std_logic_vector(7 downto 0);
    data : out std_logic_vector(15 downto 0)
  );
end entity prog_rom;

architecture rtl of prog_rom is
  type rom_t is array (0 to 255) of std_logic_vector(15 downto 0);
"""
    names = ["sum of 1..10 (expect OUT = 55)", "first 10 Fibonacci numbers", "shift-and-add multiply 13 * 11 (expect 143)",
             "ALU / flags / jumps self-test", "SUBI / JNC / back-to-back STA+LDA (expect 7 0 255 1)",
             "CALL / RET nested 4 levels (expect 12 24 28)", "5-instruction demo for the waveform (expect 12)"]
    body = ""
    for i, p in enumerate(PROGS):
        w = assemble(p)
        body += f"\n  -- PROG {i}: {names[i]}\n  constant PROG{i} : rom_t := (\n"
        for a, (m, v, c, lab) in enumerate(w):
            tag = f"{lab}: " if lab else ""
            arg = f" {v}" if m not in NOARG else ""
            cm = f"  -- {tag}{m}{arg}" + (f"   ; {c}" if c else "")
            body += f"    {a:3d} => instr(OP_{m}, {v}),{cm}\n"
        body += "    others => instr(OP_HLT, 0));\n"
    tail = """
  function select_prog(p : natural) return rom_t is
  begin
    case p is
""" + "".join(f"      when {i}      => return PROG{i};\n" for i in range(len(PROGS))) + """      when others => return PROG0;
    end case;
  end function select_prog;

  constant ROM_CONTENT : rom_t := select_prog(PROG);
begin
  data <= ROM_CONTENT(to_integer(unsigned(addr)));
end architecture rtl;
"""
    open("../src/prog_rom.vhd", "w").write(head + body + tail)
    print("wrote ../src/prog_rom.vhd")

if __name__ == "__main__":
    allok = True
    for i, (p, e) in enumerate(zip(PROGS, EXPECT)):
        w = assemble(p); out, cyc, ins = run(w)
        ok = out == e; allok &= ok
        print(f"PROG{i}: words={len(w)} instrs_executed={ins} cycles={cyc} out={out} expect={e} {'OK' if ok else 'MISMATCH'}")
    print("ALL OK" if allok else "FAIL")
    if "--gen" in sys.argv:
        gen_rom(allok)

