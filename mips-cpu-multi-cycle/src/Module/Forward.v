// Định nghĩa timescale: đơn vị thời gian 1ns, độ phân giải 1ps
`timescale 1ns / 1ps

// ============================================
// MODULE: FORWARDING UNIT
// ============================================
// Module này xử lý data forwarding để giải quyết data hazard
// Forward data từ EX/MEM/WB stage về ID stage khi có dependency
// This module forwards information
module Forward(
    // Inputs từ EX stage
    input [`OP] ex_opcode,                 // Opcode của instruction ở EX stage
    input [`REG] ex_dest,                  // Destination register ở EX stage
    input [`WORD] ex_val,                  // Giá trị từ ALU ở EX stage
    // Inputs từ MEM stage
    input [`OP] mem_opcode,                // Opcode của instruction ở MEM stage
    input [`REG] mem_dest,                  // Destination register ở MEM stage
    input [`WORD] mem_alu_val,             // ALU result ở MEM stage
    input [`WORD] mem_val,                 // Memory read data ở MEM stage (cho load)
    // Inputs từ WB stage
    input [`OP] wb_opcode,                 // Opcode của instruction ở WB stage
    input [`REG] wb_dest,                  // Destination register ở WB stage
    input [`WORD] wb_val,                  // Data ở WB stage (sẽ ghi vào register file)
    // Input: source register cần kiểm tra
    input [`REG] src,                      // Source register address (rs hoặc rt)
    // Outputs
    output reg [`WORD] data,               // Giá trị forwarded (output)
    output reg depends,                     // Flag: có dependency (output)
    output reg stall                       // Flag: cần stall (load-use hazard) (output)
);
    // ============================================
    // INSTRUCTION TYPE DETECTION
    // ============================================
    // Xác định loại instruction ở mỗi stage để quyết định forwarding
    wire ex_is_arithmetic_op;              // Flag: EX stage là arithmetic operation
    wire ex_is_link_op = ex_opcode == 3;    // Flag: EX stage là JAL (link operation)
    wire ex_is_memory_load;                // Flag: EX stage là load instruction
    wire mem_is_arithmetic_op;             // Flag: MEM stage là arithmetic operation
    wire mem_is_link_op = mem_opcode == 3; // Flag: MEM stage là JAL
    wire mem_is_memory_load;               // Flag: MEM stage là load instruction
    wire wb_is_arithmetic_op;              // Flag: WB stage là arithmetic operation
    wire wb_is_link_op = wb_opcode == 3;   // Flag: WB stage là JAL
    wire wb_is_memory_load;                // Flag: WB stage là load instruction

    /* verilator lint_off PINMISSING */
    // Xác định loại instruction ở mỗi stage
    ALUOp ex_aluop(.opcode (ex_opcode), .arithmetic_op (ex_is_arithmetic_op));
    ALUOp mem_aluop(.opcode (mem_opcode), .arithmetic_op (mem_is_arithmetic_op));
    ALUOp wb_aluop(.opcode (wb_opcode), .arithmetic_op (wb_is_arithmetic_op));
    
    MemoryOp ex_memop(.opcode (ex_opcode), .load (ex_is_memory_load));
    MemoryOp mem_memop(.opcode (mem_opcode), .load (mem_is_memory_load));
    MemoryOp wb_memop(.opcode (wb_opcode), .load (wb_is_memory_load));
    /* verilator lint_on PINMISSING */
    
    // ============================================
    // FORWARDING LOGIC
    // ============================================
    // Kiểm tra dependency và quyết định forward data từ stage nào
    always @(*) begin
        // Khởi tạo mặc định
        data = 0;
        depends = 0;
        stall = 0;
        
        // Nếu source register = 0 (r0 luôn = 0), không có dependency
        if (src == 0) begin
            data = 0;
            depends = 0;
            stall = 0;
        end 
        // Forward từ EX stage: nếu EX stage ghi vào cùng register và là arithmetic/JAL
        // Ưu tiên cao nhất: forward ALU result từ EX stage (1 cycle trước)
        else if (ex_dest == src && (ex_is_arithmetic_op || ex_is_link_op)) begin
            data = ex_val;                  // Forward ALU result từ EX stage
            stall = 0;                      // Không cần stall
            depends = 1;                     // Có dependency
        end 
        // Load-use hazard: nếu EX stage là load và ghi vào cùng register
        // Cần stall 1 cycle vì data chưa sẵn sàng (sẽ có ở MEM stage)
        else if (ex_dest == src && ex_is_memory_load) begin
            data = 0;                       // Data chưa sẵn sàng
            stall = 1;                      // Cần stall pipeline
            depends = 1;                    // Có dependency
        end 
        // Forward từ MEM stage: nếu MEM stage ghi vào cùng register và là arithmetic/JAL
        // Forward ALU result từ MEM stage (2 cycles trước)
        else if (mem_dest == src && (mem_is_arithmetic_op || mem_is_link_op)) begin
            data = mem_alu_val;             // Forward ALU result từ MEM stage
            stall = 0;                      // Không cần stall
            depends = 1;                    // Có dependency
        end 
        // Forward từ MEM stage: nếu MEM stage là load và ghi vào cùng register
        // Forward memory read data từ MEM stage (2 cycles trước)
        else if (mem_dest == src && mem_is_memory_load) begin 
            data = mem_val;                 // Forward memory read data từ MEM stage
            stall = 0;                      // Không cần stall
            depends = 1;                    // Có dependency
        end 
        // Forward từ WB stage: nếu WB stage ghi vào cùng register
        // Forward data từ WB stage (3 cycles trước, sẽ ghi vào register file)
        else if (wb_dest == src && (wb_is_arithmetic_op || wb_is_memory_load || wb_is_link_op)) begin
            data = wb_val;                  // Forward data từ WB stage
            stall = 0;                      // Không cần stall
            depends = 1;                    // Có dependency
        end
        // Nếu không có dependency, không forward, không stall
    end
endmodule
