// Định nghĩa timescale: đơn vị thời gian 1ns, độ phân giải 1ps
`timescale 1ns / 1ps

// ============================================
// MODULE: SHIFT INSTRUCTION DETECTOR
// ============================================
// Module này kiểm tra xem đây có phải là shift instruction không
// Shift instructions dùng shamt (shift amount) thay vì rs
// This module checks if an operation requires shamt
module IsShift(
    input [5:0] funct,                      // Function code từ R-type instruction (6 bits)
    output reg shift);                     // Flag: đây là shift instruction (output)

    always @ (funct) begin
        case (funct)
            6'h02: shift = 1;              // SRL: shift right logical
            6'h03: shift = 1;              // SRA: shift right arithmetic
            6'h00: shift = 1;              // SLL: shift left logical
            default: shift = 0;             // Không phải shift instruction
        endcase
    end
endmodule
