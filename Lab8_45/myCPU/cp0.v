module cp0_status(
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
wire [31:0] cp0_status;
wire cp0_status_bev;
reg  [7:0] cp0_status_im;
reg cp0_status_exl;
reg cp0_status_ie;

assign cp0_status_bev = 1'b1;
assign cp0_status = {   {9{1'b0}},      //31:23
                        cp0_status_bev, //22:22 ,bev
                        6'd0,           //21:16
                        cp0_status_im,  //15:8
                        6'd0,           //7:2
                        cp0_status_exl, //1
                        cp0_status_ie,  //0
                    } ;

endmodule