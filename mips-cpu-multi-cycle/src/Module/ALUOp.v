// Định nghĩa timescale: đơn vị thời gian 1ns, độ phân giải 1ps
`timescale 1ns / 1ps

// ============================================
// MODULE: ALU OPCODE MAPPER
// ============================================
// Module này map opcode sang ALU operation code
// Một số I-type instructions cần map sang ALU opcode khác với opcode gốc
// This module maps opcoode to ALUop
module ALUOp(
    input [5:0] opcode,                    // Opcode từ instruction (6 bits)
    output reg [5:0] ALUopcode,            // ALU operation code (output)
    output reg arithmetic_op);              // Flag: đây là arithmetic operation (output)

    always @ (opcode) begin
        case (opcode)
            // Branch instructions: dùng SUB để so sánh (rs - rt)
            // beq, bne = sub (so sánh bằng cách trừ)
            6'h04: ALUopcode = 6'h22;       // BEQ -> SUB
            6'h05: ALUopcode = 6'h22;       // BNE -> SUB
            // bgez, bltz = slt (set less than, so sánh với 0)
            6'h01: ALUopcode = 6'h2A;       // BGEZ/BLTZ -> SLT
            // bgtz, blez = slt (so sánh với 0)
            6'h06: ALUopcode = 6'h2A;       // BLEZ -> SLT
            6'h07: ALUopcode = 6'h2A;       // BGTZ -> SLT
            // Memory instructions: dùng ADD để tính địa chỉ (base + offset)
            // lb, lw, sb, sw = add (tính địa chỉ = base register + offset)
            6'h20: ALUopcode = 6'h20;       // LB -> ADD
            6'h23: ALUopcode = 6'h20;       // LW -> ADD
            6'h28: ALUopcode = 6'h20;       // SB -> ADD
            6'h2B: ALUopcode = 6'h20;       // SW -> ADD
            // jal = add (tính PC + 4)
            6'h03: ALUopcode = 6'h20;       // JAL -> ADD
            // Các instruction khác: giữ nguyên opcode
            default: ALUopcode = opcode;
        endcase
        
        // Xác định đây có phải là arithmetic operation không
        // Arithmetic operations: các phép toán số học (ADD, SUB, AND, OR, etc.)
        case (opcode)
            6'h00: arithmetic_op = 1;       // R-type (ADD, SUB, AND, OR, etc.)
            6'h08: arithmetic_op = 1;      // ADDI
            6'h09: arithmetic_op = 1;       // ADDIU
            6'h0C: arithmetic_op = 1;       // ANDI
            6'h0D: arithmetic_op = 1;       // ORI
            6'h0E: arithmetic_op = 1;       // XORI
            6'h0F: arithmetic_op = 1;       // LUI
            6'h0A: arithmetic_op = 1;       // SLTI
            6'h0B: arithmetic_op = 1;       // SLTIU
            default: arithmetic_op = 0;     // Không phải arithmetic (branch, jump, memory, etc.)
        endcase
    end
endmodule
