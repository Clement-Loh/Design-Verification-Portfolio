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

class fifo_trans #(parameter DATA_WIDTH = 8);
  bit wr_en, rd_en, parity;
  bit [DATA_WIDTH-1:0] din;
  logic [DATA_WIDTH-1:0] dout;
  
  function new(bit [DATA_WIDTH-1:0] din, bit wr_en, bit rd_en);
    this.din = din;
    this.wr_en = wr_en;
    this.rd_en = rd_en;
    this.dout = 0;
    this.parity = ^din;
  endfunction

  virtual function bit calc_parity();
    return ^din;  
  endfunction

  virtual function void display(string tag = "BASE_TRANS");
    $display("[%s] Time: %0t | wr_en=%0b | rd_en=%0b | din=0x%0h | dout=0x%0h | parity=%0b",
    tag, $time, wr_en, rd_en, din, dout, parity);
  endfunction

  virtual function fifo_trans #(DATA_WIDTH) copy();
    fifo_trans #(DATA_WIDTH) t = new(this.din, this.wr_en, this.rd_en);
    t.dout = this.dout;
    return t;
  endfunction
endclass

class bad_parity_trans #(parameter DATA_WIDTH = 8) extends fifo_trans #(DATA_WIDTH);
  function new(bit [DATA_WIDTH-1:0] din, bit wr_en, bit rd_en);
    super.new(din, wr_en, rd_en);
    this.parity = ~calc_parity();
  endfunction

  virtual function void display(string tag = "BAD_PARITY_TRANS");
    $write("BAD PARITY-");
    super.display(tag);
  endfunction
endclass


    
module tb();
  logic clk = 1'b0;
  localparam DATA_WIDTH = 8;
  localparam DEPTH = 16;
  fifo_if #(DATA_WIDTH) vif(clk);
  
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

  task drive_trans(fifo_trans #(DATA_WIDTH) t);
    @(vif.drv_cb);
    vif.drv_cb.wr_en <= t.wr_en;
    vif.drv_cb.rd_en <= t.rd_en;
    vif.drv_cb.din <= t.din;
    t.display("DRIVE_TRANS");
  endtask
  
  fifo_trans #(DATA_WIDTH) tr1, tr2;
  bad_parity_trans #(DATA_WIDTH) bad_tr;

  initial begin
    clk = 1'b0;
    vif.rst_n = 1'b0;
    vif.wr_en = 1'b0;
    vif.rd_en = 1'b0;
    vif.din = 0;
    
    repeat (2) @(vif.drv_cb);
    vif.drv_cb.rst_n <= 1'b1;
    
    $display("\nOOP TEST A: DEEP COPY (copy)");
    tr1 = new(8'hA5, 1'b1, 1'b0);
    tr2 = tr1.copy();
    tr2.din = 8'hFF;
    tr1.display("ORIG");
    tr2.display("CLONE");

    $display("\nOOP TEST B: POLYMORPHISM (pass bad_tr into drive_trans)");
    bad_tr = new(8'h55, 1'b0, 1'b0);
    drive_trans(bad_tr);

    $display("FIFO TEST 1: Burst Writing using Transaction Objects");
    for(int i=0; i<DEPTH+2;i++) begin
      tr1 = new(i, 1'b1, 1'b0);
      drive_trans(tr1);
    end
    @(vif.drv_cb);
    vif.drv_cb.wr_en <= 1'b0;

    $display("FIFO TEST 2: Read and Check");
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

    $display("========================================");
    $display(" TEST SUMMARY: PASS=%0d | ERRORS=%0d", pass_count, error_count);
    $display("========================================");
    $finish;
  end
endmodule