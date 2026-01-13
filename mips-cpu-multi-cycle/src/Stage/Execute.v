// Định nghĩa timescale: đơn vị thời gian 1ns, độ phân giải 1ps
`timescale 1ns / 1ps

// ============================================
// MODULE: EXECUTE (EX)
// ============================================
// Module này thực hiện ALU operations, xử lý branch và kiểm tra branch prediction
module Execute(
    // Inputs từ ID stage
    input [`OP] alu_op,                    // ALU operation code
    input [`WORD] alu_src1,               // ALU operand 1
    input [`WORD] alu_src2,               // ALU operand 2
    input [`OP] id_opcode,                 // Opcode (từ ID stage)
    input [`WORD] id_pc,                   // PC (từ ID stage)
    input alu_branch_mask,                 // Branch mask (từ ID stage)
    input [`WORD] branch_pc,               // Branch target address (từ ID stage)
    input [`WORD] next_pc,                 // Next PC (từ ID stage)
    input [`REG] id_rf_dest,               // Destination register (từ ID stage)
    input [`WORD] id_mem_data,            // Memory write data (từ ID stage)
    input id_branch_taken,                 // Branch prediction flag (từ ID stage)
    input force_jump,                      // Force jump flag (từ ID stage)
    // Outputs
    output [`WORD] alu_out,                // Kết quả từ ALU
    output [`OP] ex_opcode,                // Opcode (truyền qua các stage)
    output [`WORD] ex_pc,                  // PC thực tế sau khi xử lý branch (truyền qua)
    output [`REG] ex_rf_dest,              // Destination register (truyền qua)
    output [`WORD] ex_mem_data,            // Memory write data (truyền qua)
    // Branch prediction results
    output correct_branch_prediction,      // Flag: branch prediction có đúng không
    output [`WORD] branch_jump_target      // Địa chỉ nhảy nếu prediction sai
);
    // Truyền các signals qua stage (không thay đổi)
    assign ex_mem_data = id_mem_data;       // Memory write data (truyền qua)
    assign ex_rf_dest = id_rf_dest;        // Destination register (truyền qua)
    assign ex_opcode = id_opcode;          // Opcode (truyền qua)
    
    // ============================================
    // ALU OPERATION
    // ============================================
    // Zero flag từ ALU (dùng cho branch condition)
    wire alu_zero;

    // ALU module: thực hiện các phép toán (ADD, SUB, AND, OR, etc.)
    ALU alu (
            .ALUopcode (alu_op),            // ALU operation code (input)
            .op1 (alu_src1),               // Operand 1 (input)
            .op2 (alu_src2),               // Operand 2 (input)
            .out (alu_out),                // Kết quả (output)
            .zero (alu_zero));             // Zero flag: 1 nếu kết quả = 0 (output)

    // ============================================
    // BRANCH PROCESSING
    // ============================================
    // Kiểm tra xem đây có phải là branch instruction không
    wire is_branch;
    /* verilator lint_off PINMISSING */
    BranchOp branchOp(
        .opcode (id_opcode),               // Opcode để xác định loại branch
        .branch_op (is_branch)             // Output: flag cho biết đây là branch instruction
    );
    /* verilator lint_on PINMISSING */

    // Quyết định có nhảy branch không:
    // - Nếu là branch instruction VÀ điều kiện đúng thì nhảy
    // - Điều kiện: (alu_zero XOR alu_branch_mask)
    //   * BEQ: alu_branch_mask = 0, nhảy nếu alu_zero = 1 (rs == rt)
    //   * BNE: alu_branch_mask = 1, nhảy nếu alu_zero = 0 (rs != rt)
    wire take_branch = is_branch && (alu_zero ^ alu_branch_mask);
    
    // PC thực tế sau khi xử lý branch:
    // - Nếu nhảy branch: dùng branch_pc (PC + 4 + offset)
    // - Ngược lại: dùng next_pc (PC + 4 hoặc jump target)
    assign ex_pc = take_branch ? branch_pc : next_pc;

    // ============================================
    // BRANCH PREDICTION CHECK
    // ============================================
    // Kiểm tra branch prediction có đúng không:
    // - Prediction đúng nếu: (take_branch == id_branch_taken) VÀ không phải jump
    // - Prediction sai nếu: (take_branch != id_branch_taken) HOẶC là jump instruction
    assign correct_branch_prediction = 
        !((take_branch != id_branch_taken) || force_jump);

    // Địa chỉ nhảy nếu branch prediction sai:
    // - Nếu prediction sai: dùng ex_pc (PC thực tế)
    // - Nếu là jump: dùng next_pc (jump target)
    // - Ngược lại: 0 (không nhảy)
    assign branch_jump_target = (take_branch != id_branch_taken) ? ex_pc :
        (force_jump ? next_pc : 0);

endmodule
