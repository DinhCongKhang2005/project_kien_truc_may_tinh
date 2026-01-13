// Định nghĩa timescale: đơn vị thời gian 1ns, độ phân giải 1ps
`timescale 1ns / 1ps

// ============================================
// MODULE: BRANCH OPERATION DECODER
// ============================================
// Module này decode branch instructions và xác định loại branch
// This module decodes branch op
module BranchOp(
    input [5:0] opcode,                    // Opcode từ instruction (6 bits)
    output reg branch_op,                   // Flag: đây là branch instruction (output)
    output reg override_rt,                 // Flag: cần override rt value (output)
    output reg [31:0] rt_val);            // Giá trị override cho rt (output)

    always @ (*) begin
        // Xác định đây có phải là branch instruction không
        case (opcode)
            // beq: branch if equal
            6'h04: branch_op = 1;
            // bne: branch if not equal
            6'h05: branch_op = 1;
            // bgez, bltz: branch if greater/less than or equal to zero
            6'h01: branch_op = 1;
            // bgtz: branch if greater than zero
            6'h07: branch_op = 1;
            // blez: branch if less than or equal to zero
            6'h06: branch_op = 1;        
            default: branch_op = 0;         // Không phải branch instruction
        endcase
        
        // Xác định có cần override rt value không (cho các branch đặc biệt)
        case (opcode)
            // blez: so sánh rs với 0, override rt = 1 (để dùng trong ALU)
            6'h06: begin override_rt = 1; rt_val = 1; end
            // bgtz: so sánh rs với 0, override rt = 1
            6'h07: begin override_rt = 1; rt_val = 1; end
            // bgez, bltz: so sánh rs với 0, override rt = 0
            6'h01: begin override_rt = 1; rt_val = 0; end
            default: begin override_rt = 0; rt_val = 0; end
        endcase
    end
endmodule
