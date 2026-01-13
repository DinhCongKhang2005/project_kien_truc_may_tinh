// Định nghĩa timescale: đơn vị thời gian 1ns, độ phân giải 1ps
`timescale 1ns / 1ps

// ============================================
// MODULE: EXTENSION MODE SELECTOR
// ============================================
// Module này xác định cần sign-extend hay zero-extend immediate value
// Một số instructions (ANDI, ORI, XORI) cần zero-extend, các instruction khác cần sign-extend
// This module checks if an operation requires zero extenstion
module ExtMode(
    input [5:0] opcode,                    // Opcode từ instruction (6 bits)
    output reg signExt);                   // Flag: 1 = sign-extend, 0 = zero-extend (output)

    always @ (opcode) begin
        case (opcode)
            // Các instruction cần zero-extend (không dấu):
            6'h0c: signExt = 0;            // ANDI: zero-extend
            6'h0d: signExt = 0;            // ORI: zero-extend
            6'h0e: signExt = 0;            // XORI: zero-extend
            6'h24: signExt = 0;            // AND (R-type): zero-extend (không dùng)
            6'h25: signExt = 0;            // OR (R-type): zero-extend (không dùng)
            // Các instruction khác: sign-extend (có dấu)
            default: signExt = 1;          // Sign-extend (ADDI, LW, SW, etc.)
        endcase
    end
endmodule
