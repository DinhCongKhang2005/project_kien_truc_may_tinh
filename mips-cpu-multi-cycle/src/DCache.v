// Định nghĩa timescale: đơn vị thời gian 1ns, độ phân giải 1ps
`timescale 1ns / 1ps

// ============================================
// MODULE: DATA CACHE
// ============================================
// Cache cho data memory - giảm latency khi access memory
// Direct-mapped cache với 256 entries, write-invalidate policy
module DCache(
    input clk,                             // Clock signal
    input reset,                           // Reset signal
    
    // CPU Interface (từ Memory stage)
    input [31:0] address,                  // Địa chỉ memory (byte address)
    input [31:0] writeData,                // Data để ghi (cho store instructions)
    input [2:0] mode,                      // Memory access mode (1=byte, 2=word)
    input memWrite,                        // Write enable signal
    input memRead,                         // Read enable signal
    output [31:0] readData,                // Data đọc được (output)
    output ready,                          // Ready signal: 1 nếu cache hit hoặc write, 0 nếu miss
    
    // Memory Interface (kết nối với DataMemory khi miss)
    output reg [31:0] mem_addr,            // Địa chỉ gửi đến DataMemory
    output reg [31:0] mem_wdata,           // Data ghi gửi đến DataMemory
    output reg [2:0] mem_mode,             // Mode gửi đến DataMemory
    output reg mem_write_en,               // Write enable gửi đến DataMemory
    output reg mem_read_en,                // Read enable gửi đến DataMemory
    input [31:0] mem_rdata                 // Data đọc từ DataMemory (input)
);

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
    reg [31:0] cache_line [255:0];        // Cache line data (32 bits)

    // ============================================
    // ADDRESS DECODING
    // ============================================
    // Tách address thành tag và index
    wire [21:0] tag = address[31:10];      // Tag: bits 31-10 (22 bits)
    wire [7:0] index = address[9:2];       // Index: bits 9-2 (8 bits, cho 256 entries)

    // ============================================
    // CACHE HIT/MISS DETECTION
    // ============================================
    // Cache hit nếu: valid bit = 1 VÀ tag khớp
    wire hit = valid[index] && (cache_tag[index] == tag);
    
    // Ready signal:
    // - Nếu không đọc (idle hoặc write): ready = 1
    // - Nếu đọc và cache hit: ready = 1
    // - Nếu đọc và cache miss: ready = 0 (cần đợi memory)
    // Note: Với write, giả sử ready ngay lập tức (Write-Through hoặc memory nhanh)
    assign ready = (!memRead) || hit;
    
    // Read data: nếu cache hit thì trả về cache line, ngược lại trả về 0
    // (Có thể bypass từ memory nếu muốn, nhưng ở đây dùng cache logic)
    assign readData = hit ? cache_line[index] : 0;
    
    // ============================================
    // MEMORY INTERFACE LOGIC
    // ============================================
    // Kết nối với DataMemory khi cache miss hoặc write
    always @(*) begin
        mem_addr = address;                 // Địa chỉ = address từ CPU
        mem_wdata = writeData;              // Write data = writeData từ CPU
        mem_mode = mode;                    // Mode = mode từ CPU
        // Write-Through: Luôn ghi vào memory nếu CPU ghi
        mem_write_en = memWrite;
        // Đọc từ memory chỉ khi cache miss
        mem_read_en = memRead && !hit;
    end

    // ============================================
    // RESET LOGIC
    // ============================================
    integer i;
    always @ (negedge reset) begin
        for (i = 0; i < cache_size; i = i + 1) begin
            valid[i] = 0;                   // Invalidate tất cả cache entries
        end
    end

    // ============================================
    // CACHE UPDATE
    // ============================================
    // Cập nhật cache ở cạnh xuống của clock
    always @ (negedge clk) begin
        // Refill cache khi miss (đọc từ memory)
        if (memRead && !hit) begin
            // Refill on miss
            // Giả sử memory read là combinational/đủ nhanh để latch ở đây
            // Nếu memory có latency, cần state machine để xử lý
            valid[index] <= 1;                      // Set valid bit
            cache_tag[index] <= tag;                // Update tag
            cache_line[index] <= mem_rdata;         // Update cache line với data từ memory
        end
        
        // Write-invalidate policy: invalidate cache line khi write
        if (memWrite) begin
            // Invalidate on write để đảm bảo consistency (cách đơn giản nhất)
            // Vì có thể ghi byte, nhưng cache giữ word
            if (hit) valid[index] <= 0;            // Invalidate cache line nếu hit
        end
    end

endmodule
