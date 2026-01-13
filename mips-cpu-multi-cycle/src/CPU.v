// Định nghĩa timescale: đơn vị thời gian 1ns, độ phân giải 1ps
`timescale 1ns / 1ps

// Định nghĩa các macro cho kích thước bus
`define WORD 31:0  // 32-bit word (từ bit 31 đến bit 0)
`define REG 4:0    // 5-bit register address (từ bit 4 đến bit 0, cho 32 registers)
`define OP 5:0     // 6-bit opcode/funct (từ bit 5 đến bit 0)

// Module CPU chính - điều phối toàn bộ 5-stage pipeline
module CPU(
    input wire clk,    // Clock signal - đồng bộ toàn bộ pipeline
    input reset);      // Reset signal - khởi tạo lại tất cả registers về 0

    // ============================================
    // PC (Program Counter) Register
    // ============================================
    // PC lưu địa chỉ của instruction hiện tại đang được fetch
    reg [`WORD] pc;

    // ============================================
    // Branch Prediction Signals
    // ============================================
    // Signal từ Execute stage cho biết branch prediction có đúng không
    wire correct_branch_prediction;
    // Địa chỉ nhảy mới nếu branch prediction sai (cần flush pipeline)
    wire [`WORD] branch_jump_target;

    // ============================================
    // Pipeline Stall Control
    // ============================================
    // Signal từ DCache cho biết data cache đã sẵn sàng (không còn miss)
    wire dcache_ready;
    // Stall toàn bộ pipeline nếu data cache chưa sẵn sàng (đang xử lý miss)
    wire stall_pipeline = !dcache_ready;

    // ============================================
    // STAGE 1: INSTRUCTION FETCH (IF)
    // ============================================
    // Stage này fetch instruction từ instruction memory/cache

    // --- INPUT ---
    // Chọn PC: nếu branch prediction sai thì nhảy đến địa chỉ mới, ngược lại dùng PC hiện tại
    wire [`WORD] if_pc = !correct_branch_prediction ? branch_jump_target : pc;

    // --- STAGE REGISTERS ---
    // Các register lưu trữ dữ liệu giữa các clock cycle cho IF/ID pipeline register
    reg [`WORD] stage_if_inst;           // Instruction đã fetch được
    reg [`WORD] stage_if_pc;             // PC của instruction này (dùng cho branch/jump)
    reg stage_if_branch_taken;            // Flag cho biết branch prediction (luôn = 0: always not taken)

    // --- OUTPUT ---
    // Các signal output từ InstFetch module
    wire [`WORD] out_if_next_pc;         // PC của instruction tiếp theo (PC + 4)
    wire [`WORD] out_if_inst;            // Instruction đã fetch được (32-bit)
    wire [`WORD] out_if_pc;              // PC hiện tại (truyền xuống các stage sau)

    // --- INTERMEDIATE SIGNALS ---
    // Các signal nội bộ giữa Cache và InstFetch
    wire [`WORD] if_addr;                // Địa chỉ để fetch instruction (từ InstFetch)
    wire [`WORD] if_inst;                // Instruction data từ Cache
    wire if_inst_ready;                  // Signal cho biết instruction đã sẵn sàng (cache hit)

    // --- INSTRUCTION MEMORY INTERFACE ---
    // Các signal kết nối Cache với Instruction Memory
    wire [`WORD] imem_addr;              // Địa chỉ gửi đến Instruction Memory (khi cache miss)
    wire [`WORD] imem_data;              // Dữ liệu từ Instruction Memory (khi cache miss)

    // ============================================
    // INSTRUCTION CACHE MODULE
    // ============================================
    // Cache cho instruction memory - giảm latency khi fetch instruction
    Cache cache(
        .clk (clk),                      // Clock signal
        .address (if_addr),              // Địa chỉ cần fetch (từ InstFetch)
        .reset (reset),                  // Reset signal
        .data (if_inst),                 // Instruction data trả về (nếu cache hit)
        .ready (if_inst_ready),          // Signal cho biết data đã sẵn sàng (hit) hay chưa (miss)
        // MODULE: Inst Memory
        .inst_data (imem_data),          // Dữ liệu từ Instruction Memory (khi miss)
        .inst_addr (imem_addr));         // Địa chỉ gửi đến Instruction Memory (khi miss)

    // ============================================
    // INSTRUCTION MEMORY MODULE
    // ============================================
    // Memory chứa chương trình (instructions) - đọc từ file .mem
    InstMemory imem(
        .address (imem_addr),            // Địa chỉ cần đọc (từ Cache khi miss)
        .data (imem_data)                // Instruction data trả về
    );

    // ============================================
    // INSTRUCTION FETCH STAGE MODULE
    // ============================================
    // Module xử lý logic fetch instruction
    InstFetch instFetch(
        .if_pc (if_pc),                  // PC hiện tại (input)
        .inst (out_if_inst),             // Instruction đã fetch (output)
        .pc (out_if_pc),                 // PC hiện tại (output, truyền xuống stage sau)
        .next_pc (out_if_next_pc),       // PC tiếp theo = PC + 4 (output)
        .inst_pc (if_addr),              // Địa chỉ để fetch (output, gửi đến Cache)
        .inst_ready(if_inst_ready),       // Signal cho biết instruction đã sẵn sàng (input từ Cache)
        .if_inst (if_inst)               // Instruction từ Cache (input)
    );

    // --- HAZARD DETECTION ---
    // Signal từ ID stage cho biết cần stall (load-use hazard)
    wire out_id_stall;
    // Chọn PC tiếp theo: nếu stall thì giữ nguyên PC, ngược lại tăng PC
    wire [`WORD] if_next_pc = out_id_stall ? if_pc : out_if_next_pc;

    // ============================================
    // CLOCK EDGE: IF/ID PIPELINE REGISTER UPDATE
    // ============================================
    // Cập nhật pipeline register ở cạnh xuống của clock (negedge)
    always @ (negedge clk) begin
        // Chỉ cập nhật nếu pipeline không bị stall
        if (!stall_pipeline) begin
            // Chỉ cập nhật nếu ID stage không yêu cầu stall
            if (!out_id_stall) begin
                // Lưu instruction và PC vào IF/ID pipeline register
                stage_if_inst <= out_if_inst;              // Lưu instruction đã fetch
                stage_if_pc <= out_if_pc;                 // Lưu PC của instruction này
                stage_if_branch_taken <= 0;               // Branch prediction: always not taken (đơn giản)
                pc <= if_next_pc;                         // Cập nhật PC cho cycle tiếp theo
            end
            // Nếu out_id_stall = 1, giữ nguyên stage registers (stall pipeline)
        end
        // Nếu stall_pipeline = 1, giữ nguyên tất cả (do cache miss)
    end

    // ============================================
    // STAGE 2: INSTRUCTION DECODE (ID)
    // ============================================
    // Stage này decode instruction, đọc register file, xử lý forwarding và hazard detection

    // --- ID/EX PIPELINE REGISTERS ---
    // Các register lưu trữ dữ liệu từ ID stage truyền sang EX stage
    reg [`OP] stage_id_alu_op;              // ALU operation code (funct hoặc mapped opcode)
    reg [`WORD] stage_id_alu_src1;         // ALU operand 1 (từ register hoặc shamt)
    reg [`WORD] stage_id_alu_src2;         // ALU operand 2 (từ register hoặc immediate)
    reg [`OP] stage_id_opcode;              // Opcode của instruction (dùng cho control signals)
    reg [`WORD] stage_id_pc;               // PC của instruction này (dùng cho branch/jump)
    reg stage_id_alu_branch_mask;           // Branch mask (cho BEQ/BNE: 0/1)
    reg [`WORD] stage_id_branch_pc;         // Branch target address (PC + 4 + offset)
    reg [`WORD] stage_id_next_pc;          // Next PC (PC + 4 hoặc jump target)
    reg [`REG] stage_id_rf_dest;            // Destination register (rd hoặc rt)
    reg [`WORD] stage_id_mem_data;          // Data để ghi vào memory (cho store instructions)
    reg stage_id_branch_taken;              // Branch prediction flag (từ IF stage)
    reg stage_id_force_jump;                // Flag cho biết đây là jump instruction (J/JAL/JR)

    // --- ID STAGE INTERMEDIATE SIGNALS ---
    // Các signal từ InstDecode module và các module khác
    wire [`REG] out_id_forward_op1;        // Register source 1 cho forwarding unit
    wire [`REG] out_id_forward_op2;        // Register source 2 cho forwarding unit
    wire forward_depends_1;                 // Flag: operand 1 có dependency với instruction trước
    wire forward_depends_2;                 // Flag: operand 2 có dependency với instruction trước
    wire forward_stalls_1;                  // Flag: operand 1 cần stall (load-use hazard)
    wire forward_stalls_2;                  // Flag: operand 2 cần stall (load-use hazard)
    wire [`WORD] forward_result_1;         // Giá trị forwarded cho operand 1 (từ EX/MEM/WB)
    wire [`WORD] forward_result_2;         // Giá trị forwarded cho operand 2 (từ EX/MEM/WB)
    wire [`REG] rf_src1;                    // Register source 1 address (rs)
    wire [`REG] rf_src2;                    // Register source 2 address (rt)
    wire [`WORD] rf_out1;                   // Giá trị từ register source 1
    wire [`WORD] rf_out2;                   // Giá trị từ register source 2
    wire [`OP] out_id_alu_op;              // ALU operation code (output từ InstDecode)
    wire [`WORD] out_id_alu_src1;         // ALU operand 1 (output từ InstDecode)
    wire [`WORD] out_id_alu_src2;         // ALU operand 2 (output từ InstDecode)
    wire [`OP] out_id_opcode;               // Opcode (output từ InstDecode)
    wire [`WORD] out_id_pc;                // PC (output từ InstDecode)
    wire out_id_alu_branch_mask;            // Branch mask (output từ InstDecode)
    wire [`WORD] out_id_branch_pc;          // Branch target (output từ InstDecode)
    wire [`WORD] out_id_next_pc;            // Next PC (output từ InstDecode)
    wire [`REG] out_id_rf_dest;             // Destination register (output từ InstDecode)
    wire [`WORD] out_id_mem_data;           // Memory write data (output từ InstDecode)
    wire out_id_branch_taken;               // Branch prediction flag (output từ InstDecode)
    wire out_id_force_jump;                 // Force jump flag (output từ InstDecode)

    // --- EX STAGE INTERMEDIATE SIGNALS ---
    // Các signal output từ Execute stage
    wire [`WORD] out_ex_alu_out;            // Kết quả từ ALU
    wire [`OP] out_ex_opcode;               // Opcode (truyền qua các stage)
    wire [`WORD] out_ex_pc;                 // PC (truyền qua các stage)
    wire [`REG] out_ex_rf_dest;             // Destination register (truyền qua các stage)
    wire [`WORD] out_ex_mem_data;           // Data để ghi memory (truyền qua các stage)

    // --- MEM/WB PIPELINE REGISTERS ---
    // Các register lưu trữ dữ liệu từ MEM stage truyền sang WB stage
    reg [`WORD] stage_mem_pc;               // PC (truyền qua các stage)
    reg [`WORD] stage_mem_out;              // Kết quả từ memory (cho load instructions)
    reg [`WORD] stage_mem_alu_out;          // Kết quả từ ALU (cho non-load instructions)
    reg [`OP] stage_mem_opcode;             // Opcode (dùng để xác định loại instruction)
    reg [`REG] stage_mem_rf_dest;           // Destination register

    // --- MEM STAGE INTERMEDIATE SIGNALS ---
    // Các signal output từ Memory stage
    wire [`WORD] out_mem_pc;                // PC (output từ Memory stage)
    wire [`WORD] out_mem_out;                // Memory read data hoặc ALU result (output)
    wire [`WORD] out_mem_alu_out;            // ALU result (output, truyền qua)
    wire [`OP] out_mem_opcode;              // Opcode (output)
    wire [`REG] out_mem_rf_dest;            // Destination register (output)
    // Data memory interface signals
    wire [`WORD] dmem_addr;                 // Địa chỉ memory (từ ALU result)
    wire [`WORD] dmem_in;                   // Data để ghi vào memory (cho store)
    wire dmem_write;                        // Write enable signal
    wire dmem_read;                         // Read enable signal
    wire [2:0] dmem_mode;                   // Memory access mode (1=byte, 2=word)
    wire [`WORD] dmem_out;                  // Data đọc từ memory (từ DCache)

    // --- WB STAGE INTERMEDIATE SIGNALS ---
    // Các signal output từ WriteBack stage
    wire [`REG] rf_dest;                    // Destination register để ghi
    wire [`WORD] rf_data;                   // Data để ghi vào register file
    wire rf_write;                          // Write enable cho register file

    // ============================================
    // FORWARDING UNITS
    // ============================================
    // Forwarding unit 1: xử lý forwarding cho operand 1 (rs) của ALU
    // Giải quyết data hazard bằng cách forward data từ EX/MEM/WB stage về ID stage
    Forward forward1(
        .ex_opcode (out_ex_opcode),         // Opcode của instruction ở EX stage
        .ex_dest (out_ex_rf_dest),          // Destination register ở EX stage
        .ex_val (out_ex_alu_out),           // Giá trị từ ALU ở EX stage (forward nếu dependency)
        .mem_opcode (out_mem_opcode),       // Opcode của instruction ở MEM stage
        .mem_dest (out_mem_rf_dest),        // Destination register ở MEM stage
        .mem_alu_val (out_mem_alu_out),      // ALU result ở MEM stage (forward nếu dependency)
        .mem_val (out_mem_out),             // Memory read data ở MEM stage (cho load)
        .wb_opcode (stage_mem_opcode),      // Opcode của instruction ở WB stage
        .wb_dest (stage_mem_rf_dest),       // Destination register ở WB stage
        .wb_val (rf_data),                   // Data ở WB stage (forward nếu dependency)
        .src (out_id_forward_op1),          // Source register cần kiểm tra (rs)
        .data (forward_result_1),           // Giá trị forwarded (output)
        .depends (forward_depends_1),       // Flag: có dependency (output)
        .stall (forward_stalls_1)            // Flag: cần stall (load-use hazard) (output)
    );

    // Forwarding unit 2: xử lý forwarding cho operand 2 (rt) của ALU
    // Tương tự forward1 nhưng cho operand thứ 2
    Forward forward2(
        .ex_opcode (out_ex_opcode),         // Opcode của instruction ở EX stage
        .ex_dest (out_ex_rf_dest),          // Destination register ở EX stage
        .ex_val (out_ex_alu_out),           // Giá trị từ ALU ở EX stage
        .mem_opcode (out_mem_opcode),       // Opcode của instruction ở MEM stage
        .mem_dest (out_mem_rf_dest),        // Destination register ở MEM stage
        .mem_alu_val (out_mem_alu_out),      // ALU result ở MEM stage
        .mem_val (out_mem_out),             // Memory read data ở MEM stage
        .wb_opcode (stage_mem_opcode),      // Opcode của instruction ở WB stage
        .wb_dest (stage_mem_rf_dest),       // Destination register ở WB stage
        .wb_val (rf_data),                   // Data ở WB stage
        .src (out_id_forward_op2),          // Source register cần kiểm tra (rt)
        .data (forward_result_2),           // Giá trị forwarded (output)
        .depends (forward_depends_2),       // Flag: có dependency (output)
        .stall (forward_stalls_2)            // Flag: cần stall (load-use hazard) (output)
    );

    // ============================================
    // REGISTER FILE MODULE
    // ============================================
    // Chứa 32 general-purpose registers (MIPS có 32 registers)
    RegisterFile rf(
        .clk (clk),                        // Clock signal
        .src1 (rf_src1),                  // Source register 1 address (rs)
        .src2 (rf_src2),                  // Source register 2 address (rt)
        .dest (rf_dest),                  // Destination register address (rd hoặc rt)
        .data (rf_data),                  // Data để ghi vào destination register
        .write (rf_write),                // Write enable signal (từ WB stage)
        .out1 (rf_out1),                  // Giá trị của source register 1 (output)
        .out2 (rf_out2),                  // Giá trị của source register 2 (output)
        .reset (reset)                    // Reset signal
    );

    // ============================================
    // INSTRUCTION DECODE STAGE MODULE
    // ============================================
    // Module decode instruction, đọc register file, xử lý forwarding và hazard detection
    InstDecode instDecode(
        .if_pc (stage_if_pc),             // PC từ IF stage (input)
        .inst (stage_if_inst),            // Instruction từ IF stage (input)
        .if_branch_taken (stage_if_branch_taken), // Branch prediction flag (input)
        // ALU control signals (output)
        .alu_op (out_id_alu_op),          // ALU operation code
        .alu_src1 (out_id_alu_src1),     // ALU operand 1
        .alu_src2 (out_id_alu_src2),     // ALU operand 2
        .opcode (out_id_opcode),          // Opcode
        .id_pc (out_id_pc),               // PC (output)
        .alu_branch_mask (out_id_alu_branch_mask), // Branch mask (output)
        .branch_pc (out_id_branch_pc),   // Branch target address (output)
        .next_pc (out_id_next_pc),        // Next PC (output)
        .rf_dest (out_id_rf_dest),        // Destination register (output)
        .mem_data (out_id_mem_data),      // Memory write data (output)
        .id_branch_taken (out_id_branch_taken), // Branch prediction flag (output)
        .force_jump (out_id_force_jump),   // Force jump flag (output)
        .stall (out_id_stall),            // Stall signal (output, nếu có load-use hazard)
        // MODULE: Forward - kết nối với forwarding units
        .forward_op1 (out_id_forward_op1), // Source register 1 cho forwarding
        .forward_op2 (out_id_forward_op2), // Source register 2 cho forwarding
        .forward_depends_1 (forward_depends_1), // Dependency flag cho operand 1
        .forward_depends_2 (forward_depends_2), // Dependency flag cho operand 2
        .forward_stalls_1 (forward_stalls_1), // Stall flag cho operand 1
        .forward_stalls_2 (forward_stalls_2), // Stall flag cho operand 2
        .forward_result_1 (forward_result_1), // Forwarded value cho operand 1
        .forward_result_2 (forward_result_2), // Forwarded value cho operand 2
        // MODULE: RegisterFile - kết nối với register file
        .rf_src1 (rf_src1),               // Source register 1 address (output)
        .rf_src2 (rf_src2),               // Source register 2 address (output)
        .rf_out1_prev (rf_out1),          // Giá trị từ register 1 (input)
        .rf_out2_prev (rf_out2)           // Giá trị từ register 2 (input)
    );

    // ============================================
    // CLOCK EDGE: ID/EX PIPELINE REGISTER UPDATE
    // ============================================
    // Cập nhật pipeline register giữa ID và EX stage
    always @ (negedge clk) begin
        // Chỉ cập nhật nếu pipeline không bị stall
        if (!stall_pipeline) begin
            // Nếu branch prediction sai hoặc có stall request từ ID stage
            if (!correct_branch_prediction || out_id_stall) begin
                // Bubble: chèn NOP (No Operation) vào pipeline
                // Tất cả control signals = 0 để không thực hiện operation nào
                stage_id_alu_op <= 0;              // NOP: không có ALU operation
                stage_id_alu_src1 <= 0;            // NOP: operand 1 = 0
                stage_id_alu_src2 <= 0;            // NOP: operand 2 = 0
                stage_id_opcode <= 0;             // NOP: opcode = 0
                stage_id_pc <= 0;                  // NOP: PC = 0
                stage_id_alu_branch_mask <= 0;     // NOP: không branch
                stage_id_branch_pc <= 0;           // NOP: branch target = 0
                stage_id_next_pc <= 0;             // NOP: next PC = 0
                stage_id_rf_dest <= 0;            // NOP: không ghi register (r0)
                stage_id_mem_data <= 0;            // NOP: không ghi memory
                stage_id_branch_taken <= 0;        // NOP: không branch
                stage_id_force_jump <= 0;          // NOP: không jump
            end else begin
                // Bình thường: lưu tất cả signals từ ID stage vào ID/EX pipeline register
                stage_id_alu_op <= out_id_alu_op;              // ALU operation code
                stage_id_alu_src1 <= out_id_alu_src1;         // ALU operand 1
                stage_id_alu_src2 <= out_id_alu_src2;         // ALU operand 2
                stage_id_opcode <= out_id_opcode;              // Opcode
                stage_id_pc <= out_id_pc;                     // PC
                stage_id_alu_branch_mask <= out_id_alu_branch_mask; // Branch mask
                stage_id_branch_pc <= out_id_branch_pc;         // Branch target
                stage_id_next_pc <= out_id_next_pc;            // Next PC
                stage_id_rf_dest <= out_id_rf_dest;            // Destination register
                stage_id_mem_data <= out_id_mem_data;           // Memory write data
                stage_id_branch_taken <= out_id_branch_taken;  // Branch prediction flag
                stage_id_force_jump <= out_id_force_jump;       // Force jump flag
            end
        end
        // Nếu stall_pipeline = 1, giữ nguyên tất cả stage registers
    end

    // ============================================
    // STAGE 3: EXECUTE (EX)
    // ============================================
    // Stage này thực hiện ALU operations, xử lý branch và jump

    // --- EX/MEM PIPELINE REGISTERS ---
    // Các register lưu trữ dữ liệu từ EX stage truyền sang MEM stage
    reg [`WORD] stage_ex_alu_out;          // Kết quả từ ALU
    reg [`OP] stage_ex_opcode;             // Opcode (truyền qua)
    reg [`WORD] stage_ex_pc;                // PC (truyền qua)
    reg [`REG] stage_ex_rf_dest;           // Destination register (truyền qua)
    reg [`WORD] stage_ex_mem_data;          // Data để ghi memory (truyền qua)

    // ============================================
    // EXECUTE STAGE MODULE
    // ============================================
    // Module thực hiện ALU operations, xử lý branch và kiểm tra branch prediction
    Execute execute(
        .alu_op (stage_id_alu_op),          // ALU operation code (từ ID stage)
        .alu_src1 (stage_id_alu_src1),     // ALU operand 1 (từ ID stage)
        .alu_src2 (stage_id_alu_src2),     // ALU operand 2 (từ ID stage)
        .id_opcode (stage_id_opcode),       // Opcode (từ ID stage)
        .id_pc (stage_id_pc),               // PC (từ ID stage)
        .alu_branch_mask (stage_id_alu_branch_mask), // Branch mask (từ ID stage)
        .branch_pc (stage_id_branch_pc),    // Branch target (từ ID stage)
        .next_pc (stage_id_next_pc),        // Next PC (từ ID stage)
        .id_rf_dest (stage_id_rf_dest),    // Destination register (từ ID stage)
        .id_mem_data (stage_id_mem_data),   // Memory write data (từ ID stage)
        .id_branch_taken (stage_id_branch_taken), // Branch prediction (từ ID stage)
        .force_jump (stage_id_force_jump),  // Force jump flag (từ ID stage)
        // Outputs
        .alu_out (out_ex_alu_out),          // Kết quả từ ALU (output)
        .ex_opcode (out_ex_opcode),         // Opcode (output, truyền qua)
        .ex_pc (out_ex_pc),                 // PC (output, truyền qua)
        .ex_rf_dest (out_ex_rf_dest),       // Destination register (output, truyền qua)
        .ex_mem_data (out_ex_mem_data),     // Memory write data (output, truyền qua)
        // Branch prediction results
        .correct_branch_prediction (correct_branch_prediction), // Flag: prediction đúng (output)
        .branch_jump_target (branch_jump_target)                // Địa chỉ nhảy nếu sai (output)
    );

    // ============================================
    // CLOCK EDGE: EX/MEM PIPELINE REGISTER UPDATE
    // ============================================
    // Cập nhật pipeline register giữa EX và MEM stage
    always @ (negedge clk) begin
        // Chỉ cập nhật nếu pipeline không bị stall
        if (!stall_pipeline) begin
            // Lưu tất cả signals từ EX stage vào EX/MEM pipeline register
            stage_ex_alu_out <= out_ex_alu_out;        // ALU result
            stage_ex_opcode <= out_ex_opcode;           // Opcode
            stage_ex_pc <= out_ex_pc;                   // PC
            stage_ex_rf_dest <= out_ex_rf_dest;        // Destination register
            stage_ex_mem_data <= out_ex_mem_data;       // Memory write data
        end
        // Nếu stall_pipeline = 1, giữ nguyên stage registers
    end

    // ============================================
    // STAGE 4: MEMORY (MEM)
    // ============================================
    // Stage này xử lý memory access (load/store instructions)

    // ============================================
    // MEMORY STAGE MODULE
    // ============================================
    // Module xử lý memory access, kết nối với data cache và memory
    Memory memory(
        // Inputs từ EX stage
        .ex_alu_out (stage_ex_alu_out),    // ALU result (địa chỉ memory cho load/store)
        .ex_opcode (stage_ex_opcode),       // Opcode (từ EX stage)
        .ex_pc (stage_ex_pc),               // PC (từ EX stage)
        .ex_rf_dest (stage_ex_rf_dest),    // Destination register (từ EX stage)
        .ex_mem_data (stage_ex_mem_data),  // Data để ghi vào memory (cho store)
        // Outputs
        .mem_pc (out_mem_pc),               // PC (output, truyền qua)
        .mem_out (out_mem_out),             // Memory read data hoặc ALU result (output)
        .mem_alu_out (out_mem_alu_out),     // ALU result (output, truyền qua)
        .mem_opcode (out_mem_opcode),       // Opcode (output, truyền qua)
        .mem_rf_dest (out_mem_rf_dest),    // Destination register (output, truyền qua)
        // MODULE: Data Memory interface
        .dmem_out (dcache_read_data),       // Data đọc từ data cache (input)
        .dmem_addr (dmem_addr),             // Địa chỉ memory (output, gửi đến DCache)
        .dmem_in (dmem_in),                 // Data để ghi (output, gửi đến DCache)
        .dmem_write (dmem_write),           // Write enable (output, gửi đến DCache)
        .dmem_read (dmem_read),             // Read enable (output, gửi đến DCache)
        .dmem_mode (dmem_mode)              // Memory access mode (output, gửi đến DCache)
    );
    
    // ============================================
    // CLOCK EDGE: MEM/WB PIPELINE REGISTER UPDATE
    // ============================================
    // Cập nhật pipeline register giữa MEM và WB stage
    always @ (negedge clk) begin
        // Chỉ cập nhật nếu pipeline không bị stall
        if (!stall_pipeline) begin
            // Lưu tất cả signals từ MEM stage vào MEM/WB pipeline register
            stage_mem_pc <= out_mem_pc;                 // PC
            stage_mem_out <= out_mem_out;              // Memory read data hoặc ALU result
            stage_mem_alu_out <= out_mem_alu_out;      // ALU result
            stage_mem_opcode <= out_mem_opcode;        // Opcode
            stage_mem_rf_dest <= out_mem_rf_dest;      // Destination register
        end
        // Nếu stall_pipeline = 1, giữ nguyên stage registers
    end  

    // ============================================
    // DATA MEMORY & CACHE
    // ============================================

    // Signal đọc từ data cache
    wire [31:0] dcache_read_data;
    
    // Wires kết nối DCache với DataMemory (khi cache miss)
    wire [31:0] mem_addr_wire;              // Địa chỉ memory (từ DCache đến DataMemory)
    wire [31:0] mem_wdata_wire;            // Data để ghi (từ DCache đến DataMemory)
    wire [2:0] mem_mode_wire;              // Memory access mode (từ DCache đến DataMemory)
    wire mem_write_en_wire;                 // Write enable (từ DCache đến DataMemory)
    wire mem_read_en_wire;                  // Read enable (từ DCache đến DataMemory)
    wire [31:0] mem_rdata_wire;            // Data đọc từ memory (từ DataMemory đến DCache)

    // ============================================
    // DATA CACHE MODULE
    // ============================================
    // Cache cho data memory - giảm latency khi access memory
    DCache dcache(
        .clk (clk),                         // Clock signal
        .reset (reset),                     // Reset signal
        // CPU interface (từ Memory stage)
        .address (dmem_addr),               // Địa chỉ memory (input)
        .writeData (dmem_in),               // Data để ghi (input)
        .mode (dmem_mode),                  // Memory access mode (input)
        .memWrite (dmem_write),             // Write enable (input)
        .memRead (dmem_read),               // Read enable (input)
        .readData (dcache_read_data),       // Data đọc được (output, trả về Memory stage)
        .ready (dcache_ready),              // Ready signal (output, cho biết cache hit hay miss)
        // Memory interface (kết nối với DataMemory khi miss)
        .mem_addr (mem_addr_wire),          // Địa chỉ gửi đến DataMemory (output)
        .mem_wdata (mem_wdata_wire),        // Data ghi gửi đến DataMemory (output)
        .mem_mode (mem_mode_wire),          // Mode gửi đến DataMemory (output)
        .mem_write_en (mem_write_en_wire),  // Write enable gửi đến DataMemory (output)
        .mem_read_en (mem_read_en_wire),    // Read enable gửi đến DataMemory (output)
        .mem_rdata (mem_rdata_wire)         // Data đọc từ DataMemory (input)
    );

    // ============================================
    // DATA MEMORY MODULE
    // ============================================
    // Memory chứa dữ liệu - đọc/ghi byte hoặc word
    DataMemory dmem(
        .clk (clk),                         // Clock signal
        .address (mem_addr_wire),           // Địa chỉ memory (input, từ DCache)
        .writeData (mem_wdata_wire),        // Data để ghi (input, từ DCache)
        .memWrite (mem_write_en_wire),      // Write enable (input, từ DCache)
        .memRead (mem_read_en_wire),        // Read enable (input, từ DCache)
        .mode (mem_mode_wire),              // Memory access mode (input, từ DCache)
        .reset (reset),                     // Reset signal
        .readData (mem_rdata_wire)          // Data đọc được (output, trả về DCache)
    );

    // ============================================
    // STAGE 5: WRITE BACK (WB)
    // ============================================
    // Stage này quyết định ghi kết quả vào register file

    // ============================================
    // WRITE BACK STAGE MODULE
    // ============================================
    // Module quyết định data nào ghi vào register file (ALU result hay memory data)
    WriteBack writeback(
        .pc (stage_mem_pc),                 // PC (input, từ MEM stage, không dùng)
        .mem_out (stage_mem_out),          // Memory read data (input, từ MEM stage)
        .mem_rf_dest (stage_mem_rf_dest), // Destination register (input, từ MEM stage)
        .alu_out (stage_mem_alu_out),      // ALU result (input, từ MEM stage)
        .opcode (stage_mem_opcode),        // Opcode (input, từ MEM stage)
        // Outputs
        .rf_dest (rf_dest),                // Destination register để ghi (output)
        .rf_write (rf_write),              // Write enable cho register file (output)
        .rf_data (rf_data)                 // Data để ghi vào register file (output)
    );
    
    // ============================================
    // RESET LOGIC
    // ============================================
    // Khởi tạo lại tất cả registers về 0 khi reset
    always @ (negedge reset) begin
        // Reset PC về 0 (bắt đầu từ địa chỉ 0)
        pc <= 0;
        // Reset IF/ID pipeline registers
        stage_if_inst <= 0;                 // Instruction = 0 (NOP)
        stage_if_pc <= 0;                   // PC = 0
        stage_if_branch_taken <= 0;        // Branch prediction = 0
        // Reset ID/EX pipeline registers
        stage_id_alu_op <= 0;              // ALU op = 0 (NOP)
        stage_id_alu_src1 <= 0;            // Operand 1 = 0
        stage_id_alu_src2 <= 0;            // Operand 2 = 0
        stage_id_opcode <= 0;              // Opcode = 0 (NOP)
        stage_id_pc <= 0;                  // PC = 0
        stage_id_alu_branch_mask <= 0;     // Branch mask = 0
        stage_id_branch_pc <= 0;          // Branch target = 0
        stage_id_next_pc <= 0;             // Next PC = 0
        stage_id_rf_dest <= 0;            // Destination = r0 (không ghi)
        stage_id_mem_data <= 0;            // Memory data = 0
        stage_id_branch_taken <= 0;        // Branch prediction = 0
        stage_id_force_jump <= 0;         // Force jump = 0
        // Reset EX/MEM pipeline registers
        stage_ex_alu_out <= 0;             // ALU result = 0
        stage_ex_opcode <= 0;              // Opcode = 0
        stage_ex_pc <= 0;                  // PC = 0
        stage_ex_rf_dest <= 0;             // Destination = r0
        stage_ex_mem_data <= 0;             // Memory data = 0
        // Reset MEM/WB pipeline registers
        stage_mem_pc <= 0;                 // PC = 0
        stage_mem_out <= 0;                // Memory out = 0
        stage_mem_alu_out <= 0;            // ALU out = 0
        stage_mem_opcode <= 0;             // Opcode = 0
        stage_mem_rf_dest <= 0;            // Destination = r0
    end
endmodule
