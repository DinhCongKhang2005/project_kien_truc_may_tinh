// Định nghĩa timescale: đơn vị thời gian 1ns, độ phân giải 1ps
`timescale 1ns / 1ps

// ============================================
// MODULE: DATA MEMORY
// ============================================
// Module này chứa dữ liệu, hỗ trợ đọc/ghi byte hoặc word
// Little-endian byte ordering
module DataMemory(
    input clk,                             // Clock signal
    input [31:0] address,                 // Địa chỉ memory (byte address)
    input [31:0] writeData,                // Data để ghi vào memory
    input [2:0] mode,                      // Memory access mode: 1=byte, 2=word
    input memWrite,                        // Write enable signal
    input memRead,                         // Read enable signal
    input reset,                           // Reset signal
    output [31:0] readData);              // Data đọc được từ memory

    // ============================================
    // MEMORY PARAMETERS
    // ============================================
    parameter mem_size = 65536;            // Kích thước memory: 65536 bytes (64 KB)
    
    // ============================================
    // MEMORY STORAGE
    // ============================================
    // Mảng memory: 65536 bytes, mỗi byte 8 bits
    // Lưu trữ theo byte để hỗ trợ byte access
    reg [7:0] memFile [0:mem_size];
    
    // ============================================
    // WRITE OPERATION
    // ============================================
    // Ghi data vào memory ở cạnh xuống của clock
    always @ (negedge clk) begin
        if (memWrite)
            case (mode)
                // Mode 1: Ghi byte (SB instruction)
                // Ghi byte thấp nhất (bits 7:0) của writeData vào address
                1: memFile[address] <= writeData[7:0];
                // Mode 2: Ghi word (SW instruction)
                // Ghi 4 bytes theo little-endian order
                2: begin 
                    // assume little endian
                    // Byte 0 (thấp nhất) tại address
                    memFile[address] <= writeData[7:0];
                    // Byte 1 tại address + 1
                    memFile[address + 1] <= writeData[15:8];
                    // Byte 2 tại address + 2
                    memFile[address + 2] <= writeData[23:16];
                    // Byte 3 (cao nhất) tại address + 3
                    memFile[address + 3] <= writeData[31:24];
                end
            endcase
    end

    // ============================================
    // READ OPERATION
    // ============================================
    // Đọc data từ memory (combinational, không cần clock)
    assign readData = (reset || !memRead) ? 0 : (
        // Mode 1: Đọc byte (LB instruction)
        // Sign-extend byte thành 32 bits (copy bit 7 sang các bit cao)
        mode == 1 ? {{24{memFile[address][7]}}, memFile[address]} : (
            // Mode 2: Đọc word (LW instruction)
            // Đọc 4 bytes theo little-endian order và ghép thành word
            mode == 2 ? {memFile[address + 3], memFile[address + 2], memFile[address + 1], memFile[address]} : 0
        ));
endmodule
