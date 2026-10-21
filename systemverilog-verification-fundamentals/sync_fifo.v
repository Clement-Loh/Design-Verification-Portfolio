module sync_fifo #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH = 16
)(
    input wire clk,
    input wire rst_n,
    input wire wr_en,
    input wire rd_en,
    input wire [DATA_WIDTH-1:0] din,
    output reg [DATA_WIDTH-1:0] dout,
    output wire full,
    output wire empty
);

    localparam PTR_WIDTH = $clog2(DEPTH);
    reg [DATA_WIDTH-1:0] fifo_mem [0:DEPTH-1];
    reg [PTR_WIDTH:0] wr_ptr;
    reg [PTR_WIDTH:0] rd_ptr;

    assign empty = (wr_ptr == rd_ptr);
    assign full = (wr_ptr[PTR_WIDTH] != rd_ptr[PTR_WIDTH]) && (wr_ptr[PTR_WIDTH-1:0] == rd_ptr[PTR_WIDTH-1:0]);

    always @(posedge clk) begin
        if (!rst_n) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
				dout <= 0;
        end else begin
            if (wr_en && !full) begin
                fifo_mem[wr_ptr[PTR_WIDTH-1:0]] <= din;
                wr_ptr = wr_ptr + 1;
            end
            
            if (rd_en && !empty) begin
                dout <= fifo_mem[rd_ptr[PTR_WIDTH-1:0]];
                rd_ptr = rd_ptr + 1;
            end
        end
    end
endmodule