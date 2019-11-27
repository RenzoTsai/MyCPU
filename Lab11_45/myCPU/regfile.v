module regfile(
    input         clk,
    // READ PORT 1
    input  [ 4:0] raddr1,
    output [31:0] rdata1,
    // READ PORT 2
    input  [ 4:0] raddr2,
    output [31:0] rdata2,
    // WRITE PORT
    input            we,       //write enable, HIGH valid
    input  [ 4:0] waddr,
    input  [31:0] wdata
);
reg [31:0] rf[31:0];

//WRITE
always @(posedge clk) begin
    if (we) begin rf[waddr]<= wdata; end
end

//READ OUT 1
assign rdata1 = (raddr1==5'b0) ? 32'b0 : rf[raddr1];

//READ OUT 2
assign rdata2 = (raddr2==5'b0) ? 32'b0 : rf[raddr2];

endmodule

module HILO_regs(
    input         clk,
    // READ PORT 1
    
    output [31:0] rd_hi,
    // READ PORT 2
    
    output [31:0] rd_lo,
    // WRITE PORT
    input         hi_we,       //write enable, HIGH valid
    input         lo_we,       //write enable, HIGH valid
    input  [31:0] wd_hi,
    input  [31:0] wd_lo
);
reg [31:0]cp0_hi;
reg [31:0]cp0_lo;

//WRITE
always @(posedge clk) begin
    if (hi_we) cp0_hi<= wd_hi;
    if (lo_we) cp0_lo<= wd_lo;
end

//READ OUT HI
assign rd_hi = cp0_hi;

//READ OUT LO
assign rd_lo = cp0_lo;

endmodule