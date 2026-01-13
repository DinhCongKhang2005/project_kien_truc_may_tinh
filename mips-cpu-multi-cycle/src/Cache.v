// Định nghĩa timescale: đơn vị thời gian 1ns, độ phân giải 1ps
`timescale 1ns / 1ps

// ============================================
// MODULE: INSTRUCTION CACHE
// ============================================
// Cache cho instruction memory - giảm latency khi fetch instruction
// Direct-mapped cache với 256 entries
module Cache(
    input clk,                             // Clock signal
    input [`WORD] address,                 // Địa chỉ cần fetch (byte address)
    input reset,                           // Reset signal
    output[`WORD] data,                    // Instruction data (output, nếu cache hit)
    output ready,                          // Ready signal: 1 nếu cache hit, 0 nếu miss
    // MODULE: Inst Memory interface
    input [`WORD] inst_data,               // Instruction data từ Instruction Memory (khi miss)
    output reg [`WORD] inst_addr);         // Địa chỉ gửi đến Instruction Memory (khi miss)

    // ============================================
    // CACHE PARAMETERS
    // ============================================
    parameter cache_size = 256;            // Kích thước cache: 256 entries

    // ============================================
    // CACHE STORAGE
    // ============================================
    // Direct-mapped cache structure:
    reg valid [255:0];                     // Valid bit cho mỗi cache entry
    reg [21:0] cache_tag [255:0];         // Tag (22 bits) để so sánh với address
    reg [`WORD] cache_line [255:0];        // Cache line data (32 bits instruction)

    integer i;

    // ============================================
    // RESET LOGIC
    // ============================================
    // Khởi tạo tất cả valid bits về 0 khi reset
    always @ (negedge reset) begin
        for (i = 0; i < cache_size; i++) begin
            valid[i] = 0;                   // Invalidate tất cả cache entries
        end
    end
    
    // ============================================
    // ADDRESS DECODING
    // ============================================
    // Tách address thành tag và index
    // Address format: [31:10] = tag (22 bits), [9:2] = index (8 bits), [1:0] = byte offset (không dùng)
    wire [21:0] tag = address[31:10];      // Tag: bits 31-10 (22 bits)
    wire [7:0] index = address[9:2];        // Index: bits 9-2 (8 bits, cho 256 entries)

    // Tag và index của instruction address (dùng khi update cache)
    wire [21:0] inst_tag = inst_addr[31:10];
    wire [7:0] inst_index = inst_addr[9:2];

    // ============================================
    // CACHE HIT/MISS DETECTION
    // ============================================
    // Cache hit nếu: valid bit = 1 VÀ tag khớp
    assign ready = (tag == cache_tag[index] && valid[index]);
    
    // Data output: nếu cache hit thì trả về cache line, ngược lại trả về 0
    assign data = ready ? cache_line[index] : 0;

    // ============================================
    // CACHE UPDATE
    // ============================================
    // Cập nhật cache ở cạnh xuống của clock
    always @ (negedge clk) begin
        // Lưu address để dùng cho tag/index calculation
        inst_addr <= address;
        
        // Cập nhật cache với data từ Instruction Memory
        // (Luôn cập nhật, kể cả khi hit - đơn giản hóa logic)
        valid[inst_index] <= 1;                    // Set valid bit
        cache_tag[inst_index] <= inst_tag;         // Update tag
        cache_line[inst_index] <= inst_data;       // Update cache line với data từ memory
    end
endmodule
