// Định nghĩa timescale: đơn vị thời gian 1ns, độ phân giải 1ps
`timescale 1ns / 1ps

// ============================================
// MODULE: ARITHMETIC LOGIC UNIT (ALU)
// ============================================
// Module này thực hiện tất cả các phép toán số học và logic
// Hỗ trợ các instruction: ADD, SUB, AND, OR, XOR, shift, compare, etc.
module ALU(
    input [5:0] ALUopcode,                 // ALU operation code (6 bits)
    input [31:0] op1,                     // Operand 1 (32 bits)
    input [31:0] op2,                     // Operand 2 (32 bits)
    output reg [31:0] out,                // Kết quả (32 bits)
    output reg zero);                     // Zero flag: 1 nếu kết quả = 0

    // Combinational logic: thực hiện phép toán dựa trên ALUopcode
    always @ (ALUopcode or op1 or op2) begin
        case (ALUopcode)
            // ADD: cộng có dấu
            6'h20: out = op1 + op2;
            // ADDU: cộng không dấu
            6'h21: out = op1 + op2;
            // ADDI: cộng immediate có dấu
            6'h08: out = op1 + op2;
            // ADDIU: cộng immediate không dấu
            6'h09: out = op1 + op2;
            // SUB: trừ có dấu
            6'h22: out = op1 - op2;
            // SUBU: trừ không dấu
            6'h23: out = op1 - op2;
            // AND: phép AND bit
            6'h24: out = op1 & op2;
            // ANDI: AND immediate
            6'h0C: out = op1 & op2;
            // NOR: phép NOR bit (NOT OR)
            6'h27: out = ~(op1 | op2);
            // OR: phép OR bit
            6'h25: out = op1 | op2;
            // ORI: OR immediate
            6'h0D: out = op1 | op2;
            // XOR: phép XOR bit
            6'h26: out = op1 ^ op2;
            // XORI: XOR immediate
            6'h0E: out = op1 ^ op2;
            // LUI: load upper immediate (đặt 16 bit cao)
            6'h0F: out = {op2[15:0], op1[15:0]};
            // SLL: shift left logical (shift trái logic)
            6'h00: out = op2 <<< op1;
            // SLLV: shift left logical variable (shift trái logic với biến)
            6'h04: out = op2 <<< op1;
            // SRA: shift right arithmetic (shift phải số học, giữ dấu)
            6'h03: out = $signed(op2) >>> op1;
            // SRAV: shift right arithmetic variable (shift phải số học với biến)
            6'h07: out = $signed(op2) >>> op1;
            // SRL: shift right logical (shift phải logic, không dấu)
            6'h02: out = op2 >>> op1;
            // SRLV: shift right logical variable (shift phải logic với biến)
            6'h06: out = op2 >>> op1;
            // SLT: set less than (so sánh có dấu, trả về 1 nếu op1 < op2)
            6'h2A: if ($signed(op1) < $signed(op2)) out = 1; else out = 0;
            // SLTI: set less than immediate (so sánh có dấu với immediate)
            6'h0A: if ($signed(op1) < $signed(op2)) out = 1; else out = 0;
            // SLTU: set less than unsigned (so sánh không dấu)
            6'h2B: if (op1 < op2) out = 1; else out = 0;
            // SLTIU: set less than immediate unsigned (so sánh không dấu với immediate)
            6'h0B: if (op1 < op2) out = 1; else out = 0;
            // Default: kết quả = 0 (cho các opcode không hợp lệ)
            default: out = 0;
        endcase

        // Zero flag: 1 nếu kết quả = 0, 0 nếu khác 0
        // Dùng cho branch instructions (BEQ, BNE)
        if (out == 0) zero = 1; else zero = 0;
    end
endmodule
