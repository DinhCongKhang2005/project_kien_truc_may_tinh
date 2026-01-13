// Định nghĩa timescale: đơn vị thời gian 1ns, độ phân giải 1ps
`timescale 1ns / 1ps

// ============================================
// MODULE: INSTRUCTION DECODE (ID)
// ============================================
// Module này decode instruction, đọc register file, xử lý forwarding và hazard detection
// Đây là stage phức tạp nhất, xử lý nhiều loại instruction khác nhau
module InstDecode(
    // Inputs từ IF stage
    input [`WORD] inst,                    // 32-bit instruction cần decode
    input [`WORD] if_pc,                   // PC của instruction này
    input if_branch_taken,                 // Branch prediction flag từ IF stage
    // Outputs cho EX stage
    output [`OP] alu_op,                   // ALU operation code (funct hoặc mapped opcode)
    output [`WORD] alu_src1,              // ALU operand 1
    output [`WORD] alu_src2,              // ALU operand 2
    output [`OP] opcode,                   // Opcode (6 bits)
    output [`WORD] id_pc,                  // PC (truyền qua các stage)
    output alu_branch_mask,                 // Branch mask (cho BEQ/BNE)
    output [`WORD] branch_pc,              // Branch target address
    output [`WORD] next_pc,                // Next PC (PC+4 hoặc jump target)
    output [`REG] rf_dest,                 // Destination register (rd hoặc rt)
    output [`WORD] mem_data,               // Data để ghi vào memory (cho store)
    output id_branch_taken,                // Branch prediction flag (truyền qua)
    output force_jump,                     // Flag cho biết đây là jump instruction
    output stall,                          // Stall signal (nếu có load-use hazard)
    // MODULE: Forward - kết nối với forwarding units
    input forward_depends_1,                // Flag: operand 1 có dependency
    input forward_depends_2,                // Flag: operand 2 có dependency
    input forward_stalls_1,                 // Flag: operand 1 cần stall
    input forward_stalls_2,                 // Flag: operand 2 cần stall
    input [`WORD] forward_result_1,        // Forwarded value cho operand 1
    input [`WORD] forward_result_2,        // Forwarded value cho operand 2
    output wire [`REG] forward_op1,        // Source register 1 cho forwarding unit
    output wire [`REG] forward_op2,        // Source register 2 cho forwarding unit
    // MODULE: RegisterFile - kết nối với register file
    output wire [`REG] rf_src1,            // Source register 1 address (rs)
    output wire [`REG] rf_src2,             // Source register 2 address (rt)
    input wire [`WORD] rf_out1_prev,        // Giá trị từ register 1
    input wire [`WORD] rf_out2_prev        // Giá trị từ register 2
);
    // PC hiện tại
    wire [`WORD] pc = if_pc;
    
    // ============================================
    // PARSE INSTRUCTION FIELDS
    // ============================================
    // Tách các field từ 32-bit instruction theo format MIPS
    assign opcode = inst[31:26];           // Opcode: bits 31-26 (6 bits)
    wire [`REG] rs = inst[25:21];         // Source register 1: bits 25-21 (5 bits)
    wire [`REG] rt = inst[20:16];         // Source register 2: bits 20-16 (5 bits)
    wire [`REG] rd = inst[15:11];         // Destination register: bits 15-11 (5 bits, cho R-type)
    wire [`REG] shamt = inst[10:6];        // Shift amount: bits 10-6 (5 bits, cho shift instructions)
    wire [`OP] funct = inst[`OP];         // Function code: bits 5-0 (6 bits, cho R-type)
    wire [15:0] imm = inst[15:0];         // Immediate value: bits 15-0 (16 bits, cho I-type)
    // ============================================
    // IMMEDIATE EXTENSION
    // ============================================
    // Mở rộng immediate 16-bit thành 32-bit (sign-extend hoặc zero-extend)
    wire [`WORD] imm_sign_ext;             // Immediate sign-extended (cho signed operations)
    wire [`WORD] imm_zero_ext;             // Immediate zero-extended (cho unsigned operations)
    wire [`WORD] shamt_zero_ext = {{27'b0}, shamt}; // Shift amount zero-extended thành 32-bit
    
    // Module sign-extend: mở rộng immediate với dấu (copy bit 15 sang các bit cao)
    SignExt signExt(.unextended (imm), .extended (imm_sign_ext));
    // Module zero-extend: mở rộng immediate không dấu (thêm 0 vào các bit cao)
    ZeroExt zeroExt(.unextended (imm), .extended (imm_zero_ext));
    
    // ============================================
    // INSTRUCTION TYPE DETECTION
    // ============================================
    // Kiểm tra xem đây có phải là shift instruction không
    wire is_shift;
    IsShift isShift(.funct (funct), .shift (is_shift));
    
    // Kiểm tra xem đây có phải là R-type instruction không (opcode = 0)
    wire is_type_R = (opcode == 0);
    
    // Kiểm tra xem có dùng shamt không (shift instruction và R-type)
    wire use_shamt = is_shift && is_type_R;
    
    // Tính toán jump target address
    // Format: {PC[31:28], address[25:0], 2'b00} (J và JAL)
    // Hoặc giữ nguyên 4 bit cao của PC (cho absolute jump)
    wire [`WORD] jump_target = {4'b00, inst[25:0], 2'b00} | (pc & 32'hf0000000);
    
    // Flags cho biết loại instruction
    wire is_branch;                        // Flag: đây là branch instruction
    wire is_memory;                        // Flag: đây là memory instruction (load/store)

    // ============================================
    // MODULE: REGISTER FILE
    // ============================================
    // Xác định source và destination registers
    assign rf_src1 = rs;                   // Source register 1 luôn là rs
    // Source register 2: 
    // - R-type: rt (cho ALU operations)
    // - Branch: rt (để so sánh)
    // - Memory store: rt (data để ghi)
    // - Các trường hợp khác: 0 (không đọc)
    assign rf_src2 = is_type_R || is_branch || is_memory_store ? rt : 0;
    
    // Destination register:
    // - R-type: rd (destination từ field rd)
    // - JAL (opcode 3): r31 (link register)
    // - I-type khác: rt (destination từ field rt)
    assign rf_dest =  is_type_R ? rd : (
                            opcode == 3 ? 31 : rt);
    
    // Chọn giá trị từ register file hoặc forwarded value
    // Operand 1: nếu có dependency thì dùng forwarded value, ngược lại dùng từ register file
    wire [`WORD] rf_out1 = forward_depends_1 ? forward_result_1 : rf_out1_prev;
    // Operand 2: 
    // - Nếu là branch đặc biệt (bgez, bltz, etc.) thì dùng override value
    // - Nếu có dependency thì dùng forwarded value
    // - Ngược lại dùng từ register file
    wire [`WORD] rf_out2 = override_rt ? branch_alu_rt_val : 
                            (forward_depends_2 ? forward_result_2 : rf_out2_prev);
    
    // ============================================
    // MODULE: BRANCH
    // ============================================
    // Tính toán branch target address và next PC
    // Branch offset = immediate * 4 (word-aligned)
    wire [`WORD] imm_offset = imm_sign_ext <<< 2;
    // Branch target = PC + 4 + offset
    assign branch_pc = pc + 4 + imm_offset;
    
    // Next PC:
    // - J (opcode 2): jump_target
    // - JAL (opcode 3): jump_target
    // - JR (R-type, funct 8): giá trị từ rs (rf_out1)
    // - Các trường hợp khác: PC + 4
    assign next_pc = (opcode == 2 || opcode == 3) ? jump_target :
                            (opcode == 0 && funct == 8 ? rf_out1 : pc + 4);
    
    // Branch operation detection
    wire override_rt;                      // Flag: cần override rt value (cho bgez, bltz, etc.)
    wire [`WORD] branch_alu_rt_val;        // Giá trị override cho rt
    BranchOp branchOp(
        .opcode (opcode),                  // Opcode để xác định loại branch
        .branch_op (is_branch),            // Output: flag cho biết đây là branch instruction
        .override_rt (override_rt),         // Output: flag cần override rt
        .rt_val (branch_alu_rt_val)        // Output: giá trị override cho rt
    );
    
    // Branch mask: xác định điều kiện branch (BEQ: 0, BNE: 1, etc.)
    BranchOut branchOut(
        .opcode (opcode),                  // Opcode để xác định loại branch
        .rt (rt),                         // rt register (cho bgez, bltz)
        .alu_branch_mask (alu_branch_mask) // Output: branch mask
    );
    
    // Force jump flag: đây là jump instruction (J, JAL, JR)
    // Cần flush pipeline nếu branch prediction sai
    assign force_jump = opcode == 2 || opcode == 3 || (opcode == 0 && funct == 8);

    // ============================================
    // MODULE: FORWARD
    // ============================================
    // Gửi source register addresses đến forwarding units
    assign forward_op1 = rf_src1;          // Source register 1 cho forwarding unit 1
    assign forward_op2 = rf_src2;          // Source register 2 cho forwarding unit 2
    
    // Xác định ALU có dùng giá trị từ register file không
    wire alu_use_rf_out_1;                 // Flag: ALU dùng rf_out1
    wire alu_use_rf_out_2;                 // Flag: ALU dùng rf_out2
    
    // Stall condition:
    // - Operand 1 cần stall (load-use hazard)
    // - Operand 2 cần stall (load-use hazard)
    // - Memory store với operand 2 cần stall (store data chưa sẵn sàng)
    assign stall = (alu_use_rf_out_1 && forward_stalls_1) || 
                    (alu_use_rf_out_2 && forward_stalls_2) ||
                    (is_memory_store && forward_stalls_2);

    
    // ============================================
    // MODULE: MEMORY OPERATIONS
    // ============================================
    // Map opcode sang ALU operation code (cho I-type instructions)
    wire [`OP] mapped_op;
    /* verilator lint_off PINMISSING */
    // Module map opcode sang ALU opcode (ví dụ: LW/SW -> ADD để tính địa chỉ)
    ALUOp aluOp(
        .opcode (opcode),                  // Input: opcode
        .ALUopcode (mapped_op));           // Output: mapped ALU opcode
    /* verilator lint_on PINMISSING */
    
    // Memory operation detection
    wire is_memory_load;                   // Flag: đây là load instruction (LW, LB)
    wire is_memory_store;                  // Flag: đây là store instruction (SW, SB)
    wire [2:0] memory_mode;                // Memory access mode (1=byte, 2=word)
    
    // Module xác định loại memory operation
    MemoryOp memoryOp(
        .opcode (opcode),                  // Input: opcode
        .store (is_memory_store),          // Output: flag store instruction
        .load (is_memory_load),            // Output: flag load instruction
        .memory_op (is_memory),            // Output: flag memory instruction (load hoặc store)
        .memory_mode (memory_mode));       // Output: memory access mode
    
    // Data để ghi vào memory (cho store instructions)
    // Nếu có dependency thì dùng forwarded value, ngược lại dùng từ register file
    assign mem_data = forward_depends_2 ? forward_result_2 : rf_out2;

    // ============================================
    // MODULE: ALU CONTROL
    // ============================================
    // Xác định extension mode (sign-extend hay zero-extend)
    wire ext_mode;                         // Flag: sign-extend (1) hay zero-extend (0)
    ExtMode extMode (
        .opcode (opcode),                  // Input: opcode
        .signExt (ext_mode));              // Output: extension mode
    
    // ALU operation code:
    // - R-type: dùng funct field trực tiếp
    // - I-type: dùng mapped opcode từ ALUOp module
    assign alu_op = is_type_R ? funct : mapped_op;
    
    // Chọn immediate value (sign-extended hay zero-extended)
    wire [`WORD] alu_imm = ext_mode ? imm_sign_ext : imm_zero_ext;
    
    // Xác định ALU có dùng giá trị từ register file không
    // Operand 1: dùng nếu không phải shift (dùng shamt) và không phải JAL (dùng PC)
    assign alu_use_rf_out_1 = !use_shamt && opcode != 3;
    // Operand 2: dùng nếu là R-type (dùng rt) hoặc branch (dùng rt để so sánh)
    assign alu_use_rf_out_2 = is_type_R || is_branch;
    
    // ALU operand 1:
    // - Shift instructions: dùng shamt (shift amount)
    // - JAL: dùng PC (để lưu return address)
    // - Các trường hợp khác: dùng giá trị từ rs (rf_out1)
    assign alu_src1 = use_shamt ? shamt_zero_ext : 
                            (opcode == 3 ? pc : rf_out1);
    
    // ALU operand 2:
    // - R-type hoặc branch: dùng giá trị từ rt (rf_out2)
    // - JAL: dùng 4 (để tính PC+4)
    // - I-type khác: dùng immediate value (sign-extended hoặc zero-extended)
    assign alu_src2 = alu_use_rf_out_2 ? rf_out2 :
                            (opcode == 3 ? 4 : alu_imm);

    // ============================================
    // OTHER OUTPUTS
    // ============================================
    // PC hiện tại (truyền qua các stage)
    assign id_pc = pc;
    // Branch prediction flag (truyền qua các stage)
    assign id_branch_taken = if_branch_taken;
endmodule
