interface fifo_if #(
  parameter DATA_WIDTH = 8
)(
  input logic clk
);
  logic rst_n,wr_en,rd_en,full,empty;
  logic [DATA_WIDTH-1:0] din,dout;
   
  clocking drv_cb @(posedge clk);
    default input #1step output #1;
    output rst_n, wr_en, rd_en, din;
    input full, empty, dout;
  endclocking
  modport tb_mp(clocking drv_cb, input clk);
endinterface
    
module tb();
  logic clk = 1'b0;
  localparam DATA_WIDTH = 8;
  localparam DEPTH = 16;
  fifo_if #(8) vif(clk);
  
  bit [DATA_WIDTH-1:0] expected_q[$];
  bit [DATA_WIDTH-1:0] expected_dout;
  int error_count = 0;
  int pass_count = 0;
  bit expected_full;
  bit expected_empty;
  
  sync_fifo #(
    .DATA_WIDTH(DATA_WIDTH),
    .DEPTH(DEPTH)
  ) dut(
    .clk(clk),
    .rst_n(vif.rst_n),
    .wr_en(vif.wr_en),
    .rd_en(vif.rd_en),
    .din(vif.din),
    .dout(vif.dout),
    .full(vif.full),
    .empty(vif.empty)
  );
    
  always #5 clk = ~clk;
  
  always @(posedge clk) begin
    if(!vif.rst_n) begin
      expected_q.delete();
      expected_dout = 0;
    end else begin
      expected_full = (expected_q.size() == DEPTH);
      expected_empty = (expected_q.size() == 0);
      if(vif.wr_en && !expected_full) begin
        expected_q.push_back(vif.din);
      end
      
      if(vif.rd_en && !expected_empty) begin
        expected_dout <= expected_q.pop_front();
      end
    end
  end
  
  initial begin
    clk = 1'b0;
    vif.rst_n = 1'b0;
    vif.wr_en = 1'b0;
    vif.rd_en = 1'b0;
    vif.din = 0;
    
    repeat (2) @(vif.drv_cb);
    vif.drv_cb.rst_n <= 1'b1;
    
    //TEST1
    for(int i=0; i<DEPTH+2;i++) begin
      @(vif.drv_cb);
      vif.drv_cb.wr_en <= 1'b1;
      vif.drv_cb.rd_en <= 1'b0;
      vif.drv_cb.din <= i;
    end
    
    @(vif.drv_cb);
    vif.drv_cb.wr_en <= 1'b0;
    
    //TEST2
    for(int i=0; i<DEPTH+2;i++) begin
      @(vif.drv_cb);
      vif.drv_cb.rd_en <= 1'b1;
      @(vif.drv_cb);
      vif.drv_cb.rd_en <= 1'b0;
      @(vif.drv_cb);
      if(vif.drv_cb.dout === expected_dout) begin
        pass_count++;
        $display("[PASS] Time=%0t | dout=%0d matches expected_dout=%0d", $time, vif.drv_cb.dout, expected_dout);
      end else begin
        error_count++;
        $error("[FAIL] Time=%0t | dout=%0d != expected_dout=%0d", $time, vif.drv_cb.dout, expected_dout);
      end
    end
    
    @(vif.drv_cb);
    
    $display("========================================");
    $display(" TEST SUMMARY: PASS=%0d | ERRORS=%0d", pass_count, error_count);
    $display("========================================");
    $finish;
  end
endmodule