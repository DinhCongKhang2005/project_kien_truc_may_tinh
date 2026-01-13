// Định nghĩa timescale: đơn vị thời gian 1ns, độ phân giải 1ps
`timescale 1ns / 1ps

// ============================================
// MODULE: BRANCH MASK GENERATOR
// ============================================
// Module này tạo branch mask để xác định điều kiện branch
// Branch mask dùng trong ALU để quyết định có nhảy hay không
// This module generates alu for branch op
module BranchOut(
    input [5:0] opcode,                    // Opcode từ instruction (6 bits)
    input [`REG] rt,                       // rt register (dùng cho bgez, bltz)
    output reg alu_branch_mask);          // Branch mask (output)

    always @ (*) begin
        case (opcode)
            // beq: nhảy nếu rs == rt (alu_zero = 1)
            // Branch mask = 0: nhảy nếu zero = 1
            6'h04: alu_branch_mask = 0;
            // bne: nhảy nếu rs != rt (alu_zero = 0)
            // Branch mask = 1: nhảy nếu zero = 0
            6'h05: alu_branch_mask = 1;
            // bgez, bltz: nhảy dựa trên rt (rt = 0 cho bgez, rt = 1 cho bltz)
            // Branch mask = 1 nếu rt == 0 (bgez), 0 nếu rt == 1 (bltz)
            6'h01: alu_branch_mask = rt == 0;
            // bgtz: nhảy nếu rs > 0 (alu_zero = 0 và kết quả > 0)
            // Branch mask = 0: nhảy nếu zero = 0 (và kết quả > 0)
            6'h07: alu_branch_mask = 0;
            // blez: nhảy nếu rs <= 0 (alu_zero = 1 hoặc kết quả < 0)
            // Branch mask = 1: nhảy nếu zero = 1
            6'h06: alu_branch_mask = 1;
            default: alu_branch_mask = 0;
        endcase
    end
endmodule
