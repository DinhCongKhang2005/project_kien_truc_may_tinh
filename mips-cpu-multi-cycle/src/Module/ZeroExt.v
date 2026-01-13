// Định nghĩa timescale: đơn vị thời gian 1ns, độ phân giải 1ps
`timescale 1ns / 1ps

// ============================================
// MODULE: ZERO EXTENSION
// ============================================
// Module này mở rộng 16-bit immediate thành 32-bit không dấu
// Thêm 16 bits 0 vào các bit cao (16-31)
module ZeroExt(
    input [15:0] unextended,               // Immediate 16-bit (input)
    output reg [31:0] extended);          // Extended 32-bit (output)

    always @ (unextended) begin
        // Zero-extend: thêm 16 bits 0 vào bit cao
        // 16'b0: 16 bits 0
        // unextended: 16 bits gốc
        extended = {16'b0, unextended};
    end
endmodule
