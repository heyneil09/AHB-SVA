module ahb_assertion_tb;

  // Clock and Reset
  logic HCLK, HRESETn;

  // AHB Signals
  logic [31:0] HADDR;
  logic [1:0]  HTRANS;
  logic        HWRITE;
  logic [2:0]  HSIZE, HBURST;
  logic [31:0] HWDATA, HRDATA;
  logic        HREADY;
  logic [1:0]  HRESP;
  logic        HSEL;
  logic        HGRANT;

  // Instantiate Master and Slave
  ahb_master master (
    .HCLK(HCLK),
    .HRESETn(HRESETn),
    .HREADY(HREADY),
    .HRDATA(HRDATA),
    .HRESP(HRESP),
    .HADDR(HADDR),
    .HTRANS(HTRANS),
    .HWRITE(HWRITE),
    .HSIZE(HSIZE),
    .HBURST(HBURST),
    .HWDATA(HWDATA),
    .HGRANT(HGRANT)
  );

  ahb_slave slave (
    .HCLK(HCLK),
    .HRESETn(HRESETn),
    .HADDR(HADDR),
    .HTRANS(HTRANS),
    .HWRITE(HWRITE),
    .HSIZE(HSIZE),
    .HBURST(HBURST),
    .HWDATA(HWDATA),
    .HSEL(HSEL),
    .HREADY(HREADY),
    .HRDATA(HRDATA),
    .HRESP(HRESP)
  );

  // Clock generation
  initial begin
    HCLK = 0;
    forever #5 HCLK = ~HCLK;
  end

  // Reset generation
  initial begin
    HRESETn = 0;
    #20 HRESETn = 1;
  end

  // Slave selection logic (simple address decoding)
  assign HSEL = (HADDR[31:12] == 20'h0000_0); // Select slave for addresses 0x0000_0000 to 0x0000_FFFF

  // Grant signal (always grant to master in this example)
  assign HGRANT = 1'b1;

  // Test scenario
  initial begin
    #30;
    master.initiate_transfer(32'h0000_0100, 32'h1234_5678, 1'b1, 3'b000); // Write single transfer
    #100;
    master.initiate_transfer(32'h0000_0100, 32'h0000_0000, 1'b0, 3'b000); // Read single transfer
    #100;
    $finish;
  end

  // SystemVerilog Assertions (SVA) for AHB Protocol

  // 1. Control Signal Stability During Transfers
  property ahb_ctrl_stability;
    @(posedge HCLK) disable iff (!HRESETn)
    (HTRANS inside {2'b10, 2'b11} && !HREADY) |->
      ##1 ($stable(HADDR) && $stable(HTRANS) && $stable(HWRITE) && 
           $stable(HSIZE) && $stable(HBURST)) throughout (##[0:$] HREADY);
  endproperty
  assert property (ahb_ctrl_stability);

  // 2. Valid Burst Sequencing
  property ahb_burst_sequence;
    @(posedge HCLK) disable iff (!HRESETn)
    (HTRANS == 2'b10 && HBURST != 3'b000) |->
      ##1 (HTRANS inside {2'b01, 2'b11})[*0:$] ##1 (HTRANS == 2'b11);
  endproperty
  assert property (ahb_burst_sequence);

  // 3. Address Increment for INCR Bursts
  property ahb_addr_incr;
    logic [31:0] expected_addr;
    @(posedge HCLK) disable iff (!HRESETn)
    (HTRANS == 2'b10, expected_addr = HADDR + (1 << HSIZE)) |->
      ##1 (HTRANS == 2'b11) throughout (HADDR == expected_addr);
  endproperty
  assert property (ahb_addr_incr);

  // 4. Write Data Validity
  property ahb_write_data_valid;
    @(posedge HCLK) disable iff (!HRESETn)
    (HWRITE && HREADY) |-> !$isunknown(HWDATA);
  endproperty
  assert property (ahb_write_data_valid);

  // 5. Read Data Validity
  property ahb_read_data_valid;
    @(posedge HCLK) disable iff (!HRESETn)
    (!HWRITE && HREADY) |-> !$isunknown(HRDATA);
  endproperty
  assert property (ahb_read_data_valid);

  // 6. Two-Cycle Error/Retry/Split Responses
  property ahb_two_cycle_response;
    @(posedge HCLK) disable iff (!HRESETn)
    (HRESP inside {2'b01, 2'b10, 2'b11} && !HREADY) |->
      ##1 (HRESP == $past(HRESP) && HREADY);
  endproperty
  assert property (ahb_two_cycle_response);

  // 7. Arbitration and Grant
  property ahb_grant_before_transfer;
    @(posedge HCLK) disable iff (!HRESETn)
    (HTRANS inside {2'b10, 2'b11}) |-> HGRANT;
  endproperty
  assert property (ahb_grant_before_transfer);

  // 8. Slave Selection (HSEL)
  property ahb_single_hsel;
    @(posedge HCLK) disable iff (!HRESETn)
    (HTRANS inside {2'b10, 2'b11}) |-> $onehot(HSEL);
  endproperty
  assert property (ahb_single_hsel);

  // 9. Handling Error Responses
  property ahb_error_handling;
    @(posedge HCLK) disable iff (!HRESETn)
    (HRESP == 2'b01 && HREADY) |-> ##1 (HTRANS == 2'b00);
  endproperty
  assert property (ahb_error_handling);

  // Monitor for assertion failures
  initial begin
    $monitor("Time: %0t | HADDR: %h | HTRANS: %b | HWRITE: %b | HRDATA: %h | HRESP: %b",
             $time, HADDR, HTRANS, HWRITE, HRDATA, HRESP);
  end

endmodule
