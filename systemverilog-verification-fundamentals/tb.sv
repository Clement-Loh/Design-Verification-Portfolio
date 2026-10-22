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
  rand bit wr_en, rd_en;
  bit parity;
  rand bit [DATA_WIDTH-1:0] din;
  logic [DATA_WIDTH-1:0] dout;
  
  constraint c_rw_dist{
    wr_en dist {1'b0:=30, 1'b1:=70};
    rd_en dist {1'b0:=70, 1'b1:=30};
  }

  constraint c_data_dist{
    din dist {
      8'h00:=20,
      8'hFF:=20,
      [8'h01:8'hFE]:/60
    };
  }


  function new(bit [DATA_WIDTH-1:0] din = 0, bit wr_en = 0, bit rd_en = 0);
    this.din = din;
    this.wr_en = wr_en;
    this.rd_en = rd_en;
    this.dout = 0;
    this.parity = ^din;
  endfunction

  function void post_randomize();
    parity = calc_parity();
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
  bit isRead;
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
      expected_dout <= 0;
      isRead <= 0;
    end else begin
      if(isRead) begin
        if(vif.drv_cb.dout === expected_dout) begin
          pass_count++;
          $display("[PASS] Time=%0t | dout=%0d matches expected_dout=0x%0h", 
          $time, vif.drv_cb.dout, expected_dout);
        end else begin
          error_count++;
          $error("[FAIL] Time=%0t | dout=%0d != expected_dout=0x%0h",
          $time, vif.drv_cb.dout, expected_dout);
        end
      end

      expected_full = (expected_q.size() == DEPTH);
      expected_empty = (expected_q.size() == 0);

      if(vif.wr_en && !expected_full) begin
        expected_q.push_back(vif.din);
      end
      
      if(vif.rd_en && !expected_empty) begin
        expected_dout <= expected_q.pop_front();
        isRead <= 1;
      end else begin
        isRead <= 0;
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
    tr1 = new();
    
    $display("\nPHASE 1: 50 random transactions");
    for(int i=0; i<50; i++) begin
      assert(tr1.randomize()) else $error("Randomization failed");
      drive_trans(tr1);
    end

    $display("PHASE 2: Read using constraint with { }");
    for(int i=0; i<DEPTH; i++) begin
      assert(tr1.randomize() with { wr_en == 1'b0; rd_en == 1'b1; }) 
      else $error("Randomization failed");
      drive_trans(tr1);
    end

    @(vif.drv_cb);
    vif.drv_cb.wr_en <= 1'b0;
    vif.drv_cb.rd_en <= 1'b0;
    repeat (2) @(vif.drv_cb);

    $display("========================================");
    $display(" TEST SUMMARY: PASS=%0d | ERRORS=%0d", pass_count, error_count);
    $display("========================================");
    $finish;
  end
endmodule