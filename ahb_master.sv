module ahb_master (
  input  logic        HCLK, HRESETn,
  input  logic        HREADY,
  input  logic [31:0] HRDATA,
  input  logic [1:0]  HRESP,
  output logic [31:0] HADDR,
  output logic [1:0]  HTRANS,
  output logic        HWRITE,
  output logic [2:0]  HSIZE,
  output logic [2:0]  HBURST,
  output logic [31:0] HWDATA,
  output logic        HGRANT
);

  typedef enum logic [1:0] {IDLE = 2'b00, BUSY = 2'b01, NONSEQ = 2'b10, SEQ = 2'b11} trans_t;
  trans_t current_trans;

  logic [31:0] addr;
  logic [31:0] data;
  logic write_en;
  logic [2:0] burst_type;
  logic [2:0] size;

  // Initialize signals
  initial begin
    HADDR = 32'h0;
    HTRANS = IDLE;
    HWRITE = 1'b0;
    HSIZE = 3'b010; // Default to 32-bit transfers
    HBURST = 3'b000; // Single burst by default
    HWDATA = 32'h0;
    HGRANT = 1'b0;
  end

  // Master FSM
  always_ff @(posedge HCLK or negedge HRESETn) begin
    if (!HRESETn) begin
      HTRANS <= IDLE;
      HADDR <= 32'h0;
      HWDATA <= 32'h0;
      HGRANT <= 1'b0;
    end else if (HREADY) begin
      case (current_trans)
        IDLE: begin
          if (HGRANT) begin
            HTRANS <= NONSEQ;
            HADDR <= addr;
            HWRITE <= write_en;
            HBURST <= burst_type;
            HSIZE <= size;
            if (write_en) HWDATA <= data;
          end else begin
            HTRANS <= IDLE;
          end
        end
        NONSEQ: begin
          if (HBURST != 3'b000) begin // If not SINGLE burst
            HTRANS <= SEQ;
            HADDR <= HADDR + (1 << HSIZE); // Increment address
          end else begin
            HTRANS <= IDLE;
          end
        end
        SEQ: begin
          if (HBURST != 3'b000) begin
            HADDR <= HADDR + (1 << HSIZE); // Increment address
          end else begin
            HTRANS <= IDLE;
          end
        end
        default: HTRANS <= IDLE;
      endcase
    end
  end

  // Sample task to initiate a transfer
  task initiate_transfer(input logic [31:0] address, input logic [31:0] wdata, input logic write, input logic [2:0] burst);
    addr = address;
    data = wdata;
    write_en = write;
    burst_type = burst;
    current_trans = NONSEQ;
  endtask

endmodule
