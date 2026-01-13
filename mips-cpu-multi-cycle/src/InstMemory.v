// Định nghĩa timescale: đơn vị thời gian 1ns, độ phân giải 1ps
`timescale 1ns / 1ps

// ============================================
// MODULE: INSTRUCTION MEMORY
// ============================================
// Module này chứa chương trình (instructions) được load từ file .mem
// Read-only memory, chỉ đọc, không ghi
module InstMemory(
    input [31:0] address,                  // Địa chỉ cần đọc (byte address)
    output [31:0] data);                  // Instruction data (32 bits, word-aligned)

    // ============================================
    // MEMORY PARAMETERS
    // ============================================
    parameter mem_size = 65536;            // Kích thước memory: 65536 words (256 KB)
    
    // Các file memory có sẵn (comment/uncomment để chọn file test)
    // parameter mem_file = "2-basic-arithmetic.mem";
    // parameter mem_file = "3-basic-compare.mem";
    // parameter mem_file = "4-branch.mem";
    // parameter mem_file = "5-simple-mem.mem";
    parameter mem_file = "mips_hex/6-mem.mem";  // File memory mặc định
    // parameter mem_file = "load-use.mem";
    // parameter mem_file = "control-hazard.mem";
    // parameter mem_file = "data-hazard.mem.mem";

    // ============================================
    // MEMORY STORAGE
    // ============================================
    // Mảng memory: 65536 words, mỗi word 32 bits
    reg [31:0] memFile [0:mem_size];

    integer i;
    
    // ============================================
    // MEMORY INITIALIZATION
    // ============================================
    // Khởi tạo memory: tất cả = 0, sau đó load từ file
    initial begin
        // Khởi tạo tất cả memory về 0
        for(i = 0; i < mem_size; i = i + 1) begin
			memFile[i] = 0;
		end
        // Load chương trình từ file hex vào memory
        // File format: hexadecimal, mỗi dòng là một word (32 bits)
        $readmemh(mem_file, memFile);
    end

    // ============================================
    // READ OPERATION
    // ============================================
    // Đọc instruction từ memory (combinational, không cần clock)
    // Address là byte address, cần chia 4 để lấy word address (word-aligned)
    // address >>> 2: shift right 2 bits = chia 4
    assign data = memFile[address >>> 2];
endmodule
