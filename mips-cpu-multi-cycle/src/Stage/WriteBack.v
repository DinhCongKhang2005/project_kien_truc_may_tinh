// Định nghĩa timescale: đơn vị thời gian 1ns, độ phân giải 1ps
`timescale 1ns / 1ps

// ============================================
// MODULE: WRITE BACK (WB)
// ============================================
// Module này quyết định data nào ghi vào register file
// Chọn giữa ALU result và memory read data dựa trên loại instruction
module WriteBack(
    // Inputs từ MEM stage
    input [`WORD] pc,                      // PC (input, không dùng trong logic này)
    input [`WORD] mem_out,                 // Memory read data (từ MEM stage)
    input [`WORD] alu_out,                 // ALU result (từ MEM stage)
    input [`REG] mem_rf_dest,              // Destination register (từ MEM stage)
    input [`OP] opcode,                    // Opcode (từ MEM stage)
    // Outputs
    output [`REG] rf_dest,                 // Destination register để ghi (output)
    output [`WORD] rf_data,                // Data để ghi vào register file (output)
    output rf_write                        // Write enable cho register file (output)
);
    // ============================================
    // INSTRUCTION TYPE DETECTION
    // ============================================
    // Kiểm tra xem đây có phải là branch instruction không
    wire is_branch;
    /* verilator lint_off PINMISSING */
    BranchOp branchOp(
        .opcode (opcode),                   // Opcode để xác định loại branch
        .branch_op (is_branch)              // Output: flag cho biết đây là branch instruction
    );
    /* verilator lint_on PINMISSING */

    // Kiểm tra xem đây có phải là memory instruction không
    wire is_mem_store;                     // Flag: đây là store instruction
    wire is_mem_load;                      // Flag: đây là load instruction

    /* verilator lint_off PINMISSING */
    MemoryOp memoryOp(
        .opcode (opcode),                  // Opcode để xác định loại memory operation
        .store (is_mem_store),             // Output: flag store instruction
        .load (is_mem_load));              // Output: flag load instruction
    /* verilator lint_on PINMISSING */

    // ============================================
    // DATA SELECTION
    // ============================================
    // Chọn data để ghi vào register file:
    // - Load instruction: dùng memory read data (mem_out)
    // - Các instruction khác: dùng ALU result (alu_out)
    assign rf_data = is_mem_load ? mem_out : alu_out;
    
    // ============================================
    // WRITE ENABLE CONTROL
    // ============================================
    // Quyết định có ghi vào register file không:
    // - Ghi nếu: KHÔNG phải branch VÀ KHÔNG phải store VÀ KHÔNG phải J (opcode 2)
    // - Không ghi nếu: branch (không có destination), store (không ghi register), J (không có destination)
    assign rf_write = !is_branch && !is_mem_store && opcode != 2;
    
    // Destination register (truyền qua từ MEM stage)
    assign rf_dest = mem_rf_dest;
endmodule
