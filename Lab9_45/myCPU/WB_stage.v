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
    //to fs
    output [`WS_TO_FS_BUS_WD -1:0]  ws_to_fs_bus  ,
    //trace debug interface
    output [31:0] debug_wb_pc     ,
    output [ 3:0] debug_wb_rf_wen ,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata,
    output  ws_ex,
    output [ 3:0] ws_exc_type,
    output eret_flush
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
wire [ 3:0] ms_exc_type;
wire [ 3:0] ws_exc_type;
wire        ms_eret;
wire        ms_bd;
wire [31:0] ws_vaddr;
reg  [31:0] cp0_epc;
reg  [31:0] cp0_count;
reg  [31:0] cp0_compare;
reg  [31:0] cp0_badvaddr;
wire        ws_bd;

assign {ws_vaddr       ,  //117:86
        ms_bd          ,  //85:85
        ms_eret        ,  //84:84
        ms_exc_type    ,  //83:80
        ws_rd_sel      ,  //79:72
        ws_res_from_cp0,  //71:71
        mtc0_we        ,  //70:70
        ws_gr_we       ,  //69:69
        ws_dest        ,  //68:64
        ws_final_result,  //63:32
        ws_pc             //31:0
       } = ms_to_ws_bus_r;

assign ws_bd = ms_bd && ws_valid;

assign ws_exc_type = (cp0_status_ie==1&&cp0_status_exl==0&&ITR_coming)?`ITR:ms_exc_type;

wire ITR_coming;
assign ITR_coming = (cp0_cause_ip[7]&cp0_status_im[7])|
                    (cp0_cause_ip[6]&cp0_status_im[6])|
                    (cp0_cause_ip[5]&cp0_status_im[5])|
                    (cp0_cause_ip[4]&cp0_status_im[4])|
                    (cp0_cause_ip[3]&cp0_status_im[3])|
                    (cp0_cause_ip[2]&cp0_status_im[2])|
                    (cp0_cause_ip[1]&cp0_status_im[1])|
                    (cp0_cause_ip[0]&cp0_status_im[0]);


wire [31:0] wb_badvaddr;
assign wb_badvaddr = ws_vaddr;

wire        rf_we;
wire [4 :0] rf_waddr;
wire [31:0] rf_wdata;
assign ws_to_rf_bus = { ws_ex,      //42:42
                        eret_flush, //41:41
                        mtc0_we ,   //40:40
                        //cp0_epc ,   //71:40
                        ws_gr_we,   //39
                        ws_valid,   //38
                        rf_we   ,   //37:37
                        rf_waddr,   //36:32
                        rf_wdata    //31:0
                      };

assign ws_to_fs_bus = {ws_ex,eret_flush,cp0_epc};

assign ws_ready_go = !ws_ex;
assign ws_allowin  = !ws_valid || ws_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ws_valid <= 1'b0;
    end
    else if (ws_ex || eret_flush) begin
         ws_valid <= 1'b0;
    end
    else if (ws_allowin) begin
        ws_valid <= ms_to_ws_valid;
    end

    if (ms_to_ws_valid && ws_allowin) begin
        ms_to_ws_bus_r <= ms_to_ws_bus;
    end
end

assign rf_we    = ws_gr_we&&ws_valid && ws_exc_type==4'd0;
assign rf_waddr = ws_dest;
assign rf_wdata = (ws_res_from_cp0)?cp0_result:ws_final_result;




// debug info generate
assign debug_wb_pc       = ws_pc;
assign debug_wb_rf_wen   = {4{rf_we}};
assign debug_wb_rf_wnum  = ws_dest;
assign debug_wb_rf_wdata = rf_wdata;

//CP0_REG
wire [31:0] cp0_wdata;

wire eret_flush;
wire count_eq_compare;
wire [ 7:0] cp0_addr;
wire [ 4:0] wb_excode;
wire [ 5:0] ext_int_in;
assign ext_int_in = 6'd0;



assign cp0_wdata = (mtc0_we)?ws_final_result:0 ;
assign ws_ex = ((ws_exc_type!=0)?1:0)&ws_valid;

assign count_eq_compare = cp0_count==cp0_compare ;

assign wb_excode =  (ws_exc_type == `ITR     )?5'h00:
                    (ws_exc_type == `ADEL_IF )?5'h04:
                    (ws_exc_type == `RI      )?5'h0a:                    
                    (ws_exc_type == `SYSCALL )?5'h08:
                    (ws_exc_type == `BREAK   )?5'h09:
                    (ws_exc_type == `OV      )?5'h0c:
                    (ws_exc_type == `ADEL_MEM)?5'h04:
                    (ws_exc_type == `ADES    )?5'h05:
                    0;
assign eret_flush= ms_eret && ws_valid;
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
    else if (ws_ex) 
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
    else if (ws_ex && !cp0_status_exl) 
    cp0_cause_bd <= ws_bd;
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
    else if (ws_ex)
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


always @(posedge clk) begin
    
    if (ws_ex && !cp0_status_exl)
        cp0_epc <= (ws_bd) ? ws_pc - 3'h4 : ws_pc;
    else if (mtc0_we && cp0_addr==`CR_EPC) 
        cp0_epc <= cp0_wdata;
end

assign cp0_addr = ws_rd_sel;
assign ws_rd  = ws_rd_sel[7:3];
assign ws_sel = ws_rd_sel[2:0];
//利用 & |
wire [31:0] status_sel;
wire [31:0] cause_sel;
wire [31:0] epc_sel;
wire [31:0] count_sel;
wire [31:0] compare_sel;
wire [31:0] badvaddr_sel;    

assign status_sel   = (cp0_addr==`CR_STATUS  )? 32'hffffffff:32'h0;
assign cause_sel    = (cp0_addr==`CR_CAUSE   )? 32'hffffffff:32'h0;
assign epc_sel      = (cp0_addr==`CR_EPC     )? 32'hffffffff:32'h0;
assign count_sel    = (cp0_addr==`CR_COUNT   )? 32'hffffffff:32'h0;
assign compare_sel  = (cp0_addr==`CR_COMPARE )? 32'hffffffff:32'h0;
assign badvaddr_sel = (cp0_addr==`CR_BADVADDR)? 32'hffffffff:32'h0;
assign cp0_result = (status_sel   & cp0_status  ) |
                    (cause_sel    & cp0_cause   ) |
                    (epc_sel      & cp0_epc     ) |
                    (count_sel    & cp0_count   ) |
                    (compare_sel  & cp0_compare ) |
                    (badvaddr_sel & cp0_badvaddr) ;
                


//cp0_count
reg tick;

always @(posedge clk) begin
    if (reset) tick <= 1'b0;
    else tick <= ~tick;
    if (mtc0_we && cp0_addr==`CR_COUNT)
        cp0_count <= cp0_wdata;
    else if (tick)
        cp0_count <= cp0_count + 1'b1;
end


//cp0_compare

always @(posedge clk) begin
    if (mtc0_we && compare_sel) begin
        cp0_compare<=cp0_wdata;
    end
end


//cp0_badvaddr

always @(posedge clk) begin
    if (ws_ex && ws_exc_type == `ADES)
        cp0_badvaddr <= wb_badvaddr;
    else if (ws_ex && ws_exc_type == `ADEL_MEM)
        cp0_badvaddr <= wb_badvaddr;
    else if (ws_ex && ws_exc_type == `ADEL_IF)
        cp0_badvaddr <= ws_pc;
end
endmodule
