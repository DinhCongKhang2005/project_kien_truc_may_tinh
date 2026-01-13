// Định nghĩa timescale: đơn vị thời gian 1ns, độ phân giải 1ps
`timescale 1ns / 1ps

// ============================================
// MODULE: INSTRUCTION FETCH (IF)
// ============================================
// Module này xử lý việc fetch instruction từ instruction cache/memory
// Input: PC hiện tại, instruction từ cache, ready signal
// Output: Instruction, PC, next PC, địa chỉ để fetch
module InstFetch(
    input [`WORD] if_pc,      // PC hiện tại (input từ CPU)
    output [`WORD] inst,       // Instruction đã fetch được (output)
    output [`WORD] pc,         // PC hiện tại (output, truyền xuống các stage sau)
    output [`WORD] next_pc,    // PC tiếp theo = PC + 4 (output)
    output [`WORD] inst_pc,    // Địa chỉ để fetch instruction (output, gửi đến Cache)
    input inst_ready,          // Signal cho biết instruction đã sẵn sàng (input từ Cache)
    input [`WORD] if_inst      // Instruction data từ Cache (input)
);
    // Địa chỉ để fetch instruction = PC hiện tại
    // Gửi đến Cache module để kiểm tra cache hit/miss
    wire [`WORD] imem_addr = if_pc;
    
    // Địa chỉ PC của instruction này (truyền xuống các stage sau để dùng cho branch/jump)
    assign inst_pc = if_pc;
    
    // Instruction output: nếu cache ready (hit) thì trả về instruction, ngược lại trả về 0 (NOP)
    // Khi cache miss, inst_ready = 0, instruction = 0 (NOP) để không thực hiện operation
    assign inst = inst_ready ? if_inst : 0;
    
    // PC hiện tại (truyền xuống ID stage)
    assign pc = if_pc;
    
    // PC tiếp theo: nếu instruction ready thì tăng PC lên 4 bytes (next instruction)
    // Ngược lại giữ nguyên PC (đợi cache miss được xử lý)
    assign next_pc = inst_ready ? pc + 4 : pc;
endmodule
