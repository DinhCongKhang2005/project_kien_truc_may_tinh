// Định nghĩa timescale: đơn vị thời gian 1ns, độ phân giải 1ps
`timescale 1ns / 1ps

// ============================================
// MODULE: MEMORY (MEM)
// ============================================
// Module này xử lý memory access (load/store instructions)
// Kết nối với data cache và memory để đọc/ghi dữ liệu
module Memory(
    // Inputs từ EX stage
    input [`WORD] ex_alu_out,              // ALU result (địa chỉ memory cho load/store)
    input [`OP] ex_opcode,                 // Opcode (từ EX stage)
    input [`WORD] ex_pc,                   // PC (từ EX stage)
    input [`REG] ex_rf_dest,               // Destination register (từ EX stage)
    input [`WORD] ex_mem_data,             // Data để ghi vào memory (cho store)
    // Outputs
    output [`WORD] mem_pc,                  // PC (truyền qua các stage)
    output [`WORD] mem_out,                 // Memory read data hoặc ALU result
    output [`WORD] mem_alu_out,            // ALU result (truyền qua)
    output [`OP] mem_opcode,                // Opcode (truyền qua)
    output [`REG] mem_rf_dest,             // Destination register (truyền qua)
    // MODULE: Data Memory interface
    input [`WORD] dmem_out,                // Data đọc từ data cache (input)
    output [`WORD] dmem_addr,               // Địa chỉ memory (output, gửi đến DCache)
    output [`WORD] dmem_in,                // Data để ghi (output, gửi đến DCache)
    output dmem_write,                     // Write enable (output, gửi đến DCache)
    output dmem_read,                      // Read enable (output, gửi đến DCache)
    output [2:0] dmem_mode                 // Memory access mode (output, gửi đến DCache)
);
    // Truyền các signals qua stage (không thay đổi)
    assign mem_pc = ex_pc;                 // PC (truyền qua)
    assign mem_out = dmem_out;              // Memory read data (từ cache) hoặc 0 (nếu không load)
    assign mem_alu_out = ex_alu_out;        // ALU result (truyền qua, dùng cho non-load instructions)
    assign mem_opcode = ex_opcode;          // Opcode (truyền qua)
    assign mem_rf_dest = ex_rf_dest;       // Destination register (truyền qua)

    // ============================================
    // MEMORY OPERATION CONTROL
    // ============================================
    /* verilator lint_off PINMISSING */
    // Module xác định loại memory operation và tạo control signals
    MemoryOp memoryOp(
        .opcode (ex_opcode),               // Opcode để xác định loại memory operation
        .store (dmem_write),                // Output: write enable (1 nếu là store instruction)
        .load (dmem_read),                  // Output: read enable (1 nếu là load instruction)
        .memory_mode (dmem_mode));         // Output: memory access mode (1=byte, 2=word)
    /* verilator lint_on PINMISSING */
    
    // Địa chỉ memory = ALU result (đã tính từ base register + offset)
    assign dmem_addr = ex_alu_out;
    // Data để ghi vào memory = giá trị từ register (cho store instructions)
    assign dmem_in = ex_mem_data;
    
endmodule
