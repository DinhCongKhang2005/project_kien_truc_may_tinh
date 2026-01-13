// Định nghĩa timescale: đơn vị thời gian 1ns, độ phân giải 1ps
`timescale 1ns / 1ps

// ============================================
// MODULE: MEMORY OPERATION DECODER
// ============================================
// Module này decode memory instructions (load/store)
// Xác định loại memory operation và access mode
// This module decodes memory op
module MemoryOp(
    input [5:0] opcode,                    // Opcode từ instruction (6 bits)
    output reg store,                       // Flag: đây là store instruction (output)
    output reg load,                        // Flag: đây là load instruction (output)
    output reg memory_op,                   // Flag: đây là memory instruction (output)
    output reg [2:0] memory_mode);          // Memory access mode: 1=byte, 2=word (output)

    always @ (*) begin
        // Xác định đây có phải là load instruction không
        case (opcode)
            6'h20: load = 1;                // LB: load byte
            6'h23: load = 1;                // LW: load word
            default: load = 0;              // Không phải load
        endcase
        
        // Xác định đây có phải là store instruction không
        case (opcode)
            6'h28: store = 1;               // SB: store byte
            6'h2b: store = 1;                // SW: store word
            default: store = 0;             // Không phải store
        endcase
        
        // Xác định memory access mode
        case (opcode)
            // lb, sb: byte access (mode = 1)
            6'h20: memory_mode = 1;         // LB: byte mode
            6'h28: memory_mode = 1;         // SB: byte mode
            // lw, sw: word access (mode = 2)
            6'h23: memory_mode = 2;         // LW: word mode
            6'h2B: memory_mode = 2;         // SW: word mode
            default: memory_mode = 0;       // Không phải memory operation
        endcase
        
        // Memory operation: load hoặc store
        memory_op = load | store;
    end
endmodule
