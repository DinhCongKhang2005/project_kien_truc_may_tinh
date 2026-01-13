// Định nghĩa timescale: đơn vị thời gian 1ns, độ phân giải 1ps
`timescale 1ns / 1ps

// ============================================
// MODULE: SIGN EXTENSION
// ============================================
// Module này mở rộng 16-bit immediate thành 32-bit với dấu
// Copy bit 15 (MSB) sang các bit cao (16-31)
module SignExt(
    input [15:0] unextended,               // Immediate 16-bit (input)
    output reg [31:0] extended);          // Extended 32-bit (output)

    always @ (unextended) begin
        // Sign-extend: copy bit 15 (MSB) sang 16 bit cao
        // {16{unextended[15]}}: tạo 16 bits giống bit 15
        // unextended: 16 bits gốc
        extended = {{16{unextended[15]}}, unextended};
    end
endmodule
