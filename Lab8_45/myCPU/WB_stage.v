`include "mycpu.h"

module wb_stage(
    input                           clk           ,
    input                           reset         ,
    //allowin
    output                          ws_allowin    ,
    //from ms
    input                           ms_to_ws_valid,
    input  [`MS_TO_WS_BUS_WD -1:0]  ms_to_ws_bus  ,
    //to rf: for write back
    output [`WS_TO_RF_BUS_WD -1:0]  ws_to_rf_bus  ,
    //trace debug interface
    output [31:0] debug_wb_pc     ,
    output [ 3:0] debug_wb_rf_wen ,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);

reg         ws_valid;
wire        ws_ready_go;

reg [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus_r;
wire        ws_gr_we;
wire [ 4:0] ws_dest;
wire [31:0] ws_final_result;
wire [31:0] ws_pc;

wire [ 7:0] ws_rd_sel;
wire [ 4:0] ws_rd;
wire [ 2:0] ws_sel;
wire        ws_res_from_cp0;
wire        mtc0_we;
wire [31:0] cp0_result;
wire [ 2:0] ws_exc_type;

assign {
        ws_exc_type    ,  //82:80
        ws_rd_sel      ,  //79:72
        ws_res_from_cp0,  //71:71
        mtc0_we        ,  //70:70
        ws_gr_we       ,  //69:69
        ws_dest        ,  //68:64
        ws_final_result,  //63:32
        ws_pc             //31:0
       } = ms_to_ws_bus_r;

wire        rf_we;
wire [4 :0] rf_waddr;
wire [31:0] rf_wdata;
assign ws_to_rf_bus = { 
                        ws_gr_we,   //39
                        ws_valid,   //38
                        rf_we   ,   //37:37
                        rf_waddr,   //36:32
                        rf_wdata    //31:0
                      };

assign ws_ready_go = 1'b1;
assign ws_allowin  = !ws_valid || ws_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ws_valid <= 1'b0;
    end
    else if (ws_allowin) begin
        ws_valid <= ms_to_ws_valid;
    end

    if (ms_to_ws_valid && ws_allowin) begin
        ms_to_ws_bus_r <= ms_to_ws_bus;
    end
end

assign rf_we    = ws_gr_we&&ws_valid;
assign rf_waddr = ws_dest;
assign rf_wdata = (ws_res_from_cp0)?cp0_result:ws_final_result;
assign cp0_wdata = (mtc0_we)?ws_final_result:0 ;

// debug info generate
assign debug_wb_pc       = ws_pc;
assign debug_wb_rf_wen   = {4{rf_we}};
assign debug_wb_rf_wnum  = ws_dest;
assign debug_wb_rf_wdata = rf_wdata;

//CP0_REG
wire [31:0] cp0_wdata;
wire wb_ex;
wire wb_bd;
wire eret_flush;
wire mtc0_we;
wire count_eq_compare;
wire [ 7:0] cp0_addr;
wire [ 4:0] wb_excode;
wire [ 5:0] ext_int_in;


assign wb_ex = (ws_exc_type!=0)?1:0;
assign count_eq_compare = 1'b0;
assign wb_excode = (ws_exc_type==`SYSCALL)?5'h08:0;
assign eret_flush= (ws_exc_type==`SYSCALL)?1:0;
//cp0_status
wire [31:0] cp0_status;
wire cp0_status_bev;
reg  [ 7:0] cp0_status_im;
reg  cp0_status_exl;
reg  cp0_status_ie;
assign cp0_status_bev = 1'b1;

always @(posedge clk) begin
    if (mtc0_we && cp0_addr==`CR_STATUS) 
        cp0_status_im <= cp0_wdata[15:8];
end

always @(posedge clk) begin
    if (reset)
        cp0_status_exl <= 1'b0;
    else if (wb_ex) 
        cp0_status_exl <= 1'b1;
    else if (eret_flush) 
        cp0_status_exl <= 1'b0;
    else if (mtc0_we && cp0_addr==`CR_STATUS) 
        cp0_status_exl <= cp0_wdata[1];
end

always @(posedge clk ) begin
    if (reset)
        cp0_status_ie <= 1'b0;
    else if (mtc0_we && cp0_addr==`CR_STATUS) 
        cp0_status_ie <= cp0_wdata[0];
end

assign cp0_status = {   {9{1'b0}},      //31:23
                        cp0_status_bev, //22    
                        6'd0,           //21:16
                        cp0_status_im,  //15:8
                        6'd0,           //7:2
                        cp0_status_exl, //1
                        cp0_status_ie   //0
                    } ;

//cp0_cause
wire [31:0] cp0_cause;
reg cp0_cause_bd;
reg cp0_cause_ti;
reg [7:0] cp0_cause_ip;
reg [4:0] cp0_cause_excode;

always @(posedge clk) begin
    if (reset)
    cp0_cause_bd <= 1'b0;
    else if (wb_ex && !cp0_status_exl) 
    cp0_cause_bd <= wb_bd;
end

always @(posedge clk) begin
    if (reset)
        cp0_cause_ti <= 1'b0;
    else if (mtc0_we && cp0_addr==`CR_COMPARE) 
        cp0_cause_ti <= 1'b0;
    else if (count_eq_compare) 
        cp0_cause_ti <= 1'b1;
end

always @(posedge clk) begin
    if (reset)
        cp0_cause_ip[7:2] <= 6'b0;
    else begin
        cp0_cause_ip[7] <= ext_int_in[5] | cp0_cause_ti; 
        cp0_cause_ip[6:2] <= ext_int_in[4:0];
    end 
end


always @(posedge clk) begin
    if (reset)
        cp0_cause_ip[1:0] <= 2'b0;
    else if (mtc0_we && cp0_addr==`CR_CAUSE) 
        cp0_cause_ip[1:0] <= cp0_wdata[9:8];
end

always @(posedge clk) begin
    if (reset)
        cp0_cause_excode <= 5'b0;
    else if (wb_ex)
        cp0_cause_excode <= wb_excode;
end

assign cp0_cause =  {   cp0_cause_bd,     //31
                        cp0_cause_ti,     //30
                        {14{1'b0}},       //29:16
                        cp0_cause_ip,     //15:8
                        1'b0,             //7
                        cp0_cause_excode, //6:2
                        {2{1'b0}}         //1:0  
                    } ;

//cp0_epc
reg [31:0] cp0_epc;

always @(posedge clk) begin
    if (wb_ex && !cp0_status_exl)
        cp0_epc <= wb_bd ? ws_pc – 3'h4 : ws_pc;
    else if (mtc0_we && cp0_addr==`CR_EPC) 
        cp0_epc <= cp0_wdata;
end

assign cp0_addr = ws_rd_sel;
assign ws_rd  = ws_rd_sel[7:3];
assign ws_sel = ws_rd_sel[2:0];
assign cp0_result = (ws_rd==12 && ws_sel==0)? cp0_status:
                    (ws_rd==13 && ws_sel==0)? cp0_cause:
                    (ws_rd==14 && ws_sel==0)? cp0_epc:
                    0;
endmodule
