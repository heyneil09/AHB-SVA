module ahb_slave (
  input  logic        HCLK, HRESETn,
  input  logic [31:0] HADDR,
  input  logic [1:0]  HTRANS,
  input  logic        HWRITE,
  input  logic [2:0]  HSIZE,
  input  logic [2:0]  HBURST,
  input  logic [31:0] HWDATA,
  input  logic        HSEL,
  output logic        HREADY,
  output logic [31:0] HRDATA,
  output logic [1:0]  HRESP
);

  logic [31:0] memory [0:1023]; // 1KB memory for the slave
  logic [31:0] addr_reg;
  logic [31:0] data_reg;
  logic write_reg;
  logic [2:0] size_reg;

  // Initialize signals
  initial begin
    HREADY = 1'b1;
    HRDATA = 32'h0;
    HRESP = 2'b00; // OKAY response by default
  end

  // Slave FSM
  always_ff @(posedge HCLK or negedge HRESETn) begin
    if (!HRESETn) begin
      HREADY <= 1'b1;
      HRDATA <= 32'h0;
      HRESP <= 2'b00;
    end else if (HSEL && HTRANS inside {NONSEQ, SEQ}) begin
      if (HWRITE) begin
        // Write operation
        memory[HADDR[11:2]] <= HWDATA; // Simple address decoding
        HREADY <= 1'b1;
        HRESP <= 2'b00;
      end else begin
        // Read operation
        HRDATA <= memory[HADDR[11:2]]; // Simple address decoding
        HREADY <= 1'b1;
        HRESP <= 2'b00;
      end
    end else begin
      HREADY <= 1'b1;
      HRESP <= 2'b00;
    end
  end

endmodule
