// Định nghĩa timescale: đơn vị thời gian 1ns, độ phân giải 1ps
`timescale 1ns / 1ps

// ============================================
// MODULE: REGISTER FILE
// ============================================
// Module này chứa 32 general-purpose registers của MIPS
// Hỗ trợ đọc 2 registers đồng thời và ghi 1 register
module RegisterFile(
    input clk,                             // Clock signal
    input [4:0] src1,                      // Source register 1 address (rs)
    input [4:0] src2,                      // Source register 2 address (rt)
    input [4:0] dest,                      // Destination register address (rd hoặc rt)
    input [31:0] data,                     // Data để ghi vào destination register
    input write,                           // Write enable signal
    input reset,                           // Reset signal
    output wire [31:0] out1,               // Giá trị của source register 1 (output)
    output wire [31:0] out2);             // Giá trị của source register 2 (output)

    // ============================================
    // REGISTER STORAGE
    // ============================================
    // Mảng 32 registers, mỗi register 32 bits
    reg [31:0] regs [31:0];

    integer i;

    // ============================================
    // RESET LOGIC
    // ============================================
    // Khởi tạo tất cả registers về 0 khi reset
    always @ (negedge reset) begin
        for (i = 0; i < 32; i = i + 1) begin
            regs[i] = 0;                    // Reset tất cả registers về 0
        end
    end
    
    // ============================================
    // WRITE OPERATION
    // ============================================
    // Ghi data vào destination register ở cạnh xuống của clock
    always @ (negedge clk) begin
        if (write) begin
            regs[dest] <= data;            // Ghi data vào destination register
        end
        // Lưu ý: r0 (register 0) luôn = 0, nhưng vẫn có thể ghi (không ảnh hưởng)
    end

    // ============================================
    // READ OPERATION
    // ============================================
    // Đọc giá trị từ source registers (combinational, không cần clock)
    // r0 (register 0) luôn trả về 0, bất kể giá trị thực tế
    assign out1 = (src1 == 0 || reset) ? 0 : regs[src1];
    assign out2 = (src2 == 0 || reset) ? 0 : regs[src2];
endmodule
