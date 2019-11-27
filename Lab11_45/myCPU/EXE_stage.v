`include "mycpu.h"

module exe_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ms_allowin    ,
    output                         es_allowin    ,
    //from ds
    input                          ds_to_es_valid,
    input  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to ms
    output                         es_to_ms_valid,
    output [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    // data sram interface
    output reg    data_sram_en   ,
    output        data_sram_wen  ,
    output [ 1:0] data_sram_size ,
    output [31:0] data_sram_addr ,
    output [31:0] data_sram_wdata,
    input         data_addr_ok,
    input         data_data_ok,



    output out_es_valid,
    input  ws_ex,
    input  [ 3:0] ms_exc_type,
    input  [ 3:0] ws_exc_type,
    input  ms_eret,
    input  eret_flush
);



reg         es_valid      ;
wire        es_ready_go   ;
assign out_es_valid=es_valid ;

reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;
wire [15:0] es_alu_op     ;
wire        es_load_op    ;
wire        es_src1_is_sa ;  
wire        es_src1_is_pc ;
wire        es_src2_is_imm; 
wire        es_src2_is_uimm;
wire        es_src2_is_8  ;
wire        es_gr_we      ;
wire        es_mem_we     ;
wire [ 4:0] es_dest       ;
wire [15:0] es_imm        ;
wire [31:0] es_rs_value   ;
wire [31:0] es_rt_value   ;
wire [31:0] es_pc         ;

wire [ 2:0] es_load_type;
wire [31:0] es_vaddr;
wire [ 2:0] es_store_type;
wire [ 3:0] write_strb;
wire [31:0] store_data;

wire es_hi_we;
wire es_lo_we;
wire dest_is_hi;
wire dest_is_lo;
wire es_res_from_hi;
wire es_res_from_lo;
wire [31:0]es_result;
wire mult_op;
wire multu_op;
wire div_op;
wire divu_op;

assign mult_op  = es_alu_op[12];
assign multu_op = es_alu_op[13];
assign div_op  = es_alu_op[14] ;
assign divu_op = es_alu_op[15] ;

wire es_alu_overflow;


wire [31:0] es_divisor_tdata;
wire es_divisor_tready;
reg es_divisor_tvalid_r;
wire es_divisor_tvalid;
wire [31:0] es_dividend_tdata;
wire es_dividend_tready;
reg es_dividend_tvalid_r;
wire es_dividend_tvalid;
wire [63:0] es_dout_tdata;
wire es_dout_tvalid;

wire [31:0] es_divisor_tdata_u;
wire es_divisor_tready_u;
reg es_divisor_tvalid_u_r;
wire es_divisor_tvalid_u;
wire [31:0] es_dividend_tdata_u;
wire es_dividend_tready_u;
reg es_dividend_tvalid_u_r;
wire es_dividend_tvalid_u;
wire [63:0] es_dout_tdata_u;
wire es_dout_tvalid_u;


wire [ 7:0] es_rd_sel;
wire        es_res_from_cp0;
wire        es_mtc0_we;
wire [ 3:0] es_exc_type;
wire        es_eret;
wire        es_bd;
wire [ 3:0] ds_exc_type;
wire        es_inst_ov;
wire        ds_bd;

assign {es_inst_ov     ,  //167:167
        ds_bd          ,  //166:166
        es_eret        ,  //165:165
        ds_exc_type    ,  //164:161
        es_rd_sel      ,  //160:153
        es_res_from_cp0,  //152:152
        es_mtc0_we     ,  //151:151
        es_store_type  ,  //150:148
        es_load_type   ,  //147:145
        es_src2_is_uimm,  //144:144
        es_res_from_hi ,  //143:143
        es_res_from_lo ,  //142:142
        dest_is_hi     ,  //141:141
        dest_is_lo     ,  //140:140
        es_alu_op      ,  //139:124
        es_load_op     ,  //123:123
        es_src1_is_sa  ,  //122:122
        es_src1_is_pc  ,  //121:121
        es_src2_is_imm ,  //120:120
        es_src2_is_8   ,  //119:119
        es_gr_we       ,  //118:118
        es_mem_we      ,  //117:117
        es_dest        ,  //116:112
        es_imm         ,  //111:96
        es_rs_value    ,  //95 :64
        es_rt_value    ,  //63 :32
        es_pc             //31 :0
       } = ds_to_es_bus_r;

wire OV_EXE;

assign OV_EXE = es_inst_ov & es_alu_overflow ;

wire ADES_EXE;

assign ADES_EXE = (es_store_type==`SW_TYPE  &&  es_vaddr[1:0]!=2'b00)?1:
                  (es_store_type==`SH_TYPE  &&  es_vaddr[0]  !=1'b0) ?1:
                  0;

assign es_exc_type = (ds_exc_type==4'd0 && OV_EXE  )? `OV:
                     (ds_exc_type==4'd0 && ADES_EXE)? `ADES: ds_exc_type;

wire [31:0] es_alu_src1   ;
wire [31:0] es_alu_src2   ;
wire [31:0] es_alu_result ;
wire [31:0] es_alu_hi_result ;
wire [31:0] es_alu_lo_result ;
wire [31:0] es_hi_result ;
wire [31:0] es_lo_result ;
wire [31:0] hi_rdata;
wire [31:0] lo_rdata;
wire [31:0] hi_wdata;
wire [31:0] lo_wdata;


wire        es_res_from_mem;

assign es_res_from_mem = es_load_op;

assign es_bd = ds_bd && es_valid;

assign es_to_ms_bus = {es_mem_we      ,  //154:154
                       es_vaddr[31:2] ,  //153:124
                       es_bd          ,  //123:123
                       es_eret        ,  //122:122
                       es_exc_type    ,  //121:118
                       es_rd_sel      ,  //117:110
                       es_res_from_cp0,  //109:109
                       es_mtc0_we     ,  //108:108
                       es_rt_value    ,  //107:76
                       es_vaddr[1:0]  ,  //75:74
                       es_load_type   ,  //73:71  
                       es_res_from_mem,  //70:70
                       es_gr_we       ,  //69:69
                       es_dest        ,  //68:64
                       es_result      ,  //63:32  -> including: es_alu_result or (hi/lo)
                       es_pc             //31:0
                      };

assign es_ready_go    = (!(div_op && !es_dout_tvalid) && !(divu_op && !es_dout_tvalid_u))&&(!es_mem_we && !es_load_op || data_addr_ok);
assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid =  es_valid && es_ready_go;
always @(posedge clk) begin
    if (reset) begin
        es_valid <= 1'b0;
    end
    else if (ws_ex || eret_flush) begin
       es_valid <= 1'b0;
    end
    else if (es_allowin) begin
        es_valid <= ds_to_es_valid;
    end

    if (ds_to_es_valid && es_allowin) begin
        ds_to_es_bus_r <= ds_to_es_bus;
    end
end

assign es_alu_src1 = es_src1_is_sa  ? {27'b0, es_imm[10:6]} : 
                     es_src1_is_pc  ? es_pc[31:0] :
                                      es_rs_value;
assign es_alu_src2 = es_src2_is_imm ? {{16{es_imm[15]}}, es_imm[15:0]} : 
                     es_src2_is_uimm? {{16{1'b0}}, es_imm[15:0]}:
                     es_src2_is_8   ? 32'd8 :
                                      es_rt_value;
//Handle mult & div:

//handle divid and unsigned divid
assign es_dividend_tdata = es_alu_src1 ;
assign es_divisor_tdata  = es_alu_src2 ;
assign es_dividend_tdata_u = es_alu_src1 ;
assign es_divisor_tdata_u  = es_alu_src2 ;

assign es_divisor_tvalid = es_divisor_tvalid_r;
assign es_dividend_tvalid = es_dividend_tvalid_r;
assign es_divisor_tvalid_u = es_divisor_tvalid_u_r;
assign es_dividend_tvalid_u = es_dividend_tvalid_u_r;

assign es_hi_result = (div_op  && es_dout_tvalid  )?es_dout_tdata[31:0]:
                      (divu_op && es_dout_tvalid_u)?es_dout_tdata_u[31:0]: 
                      (mult_op || multu_op        )?es_alu_hi_result:
                      0;
assign es_lo_result = (div_op  && es_dout_tvalid  )?es_dout_tdata[63:32]:
                      (divu_op && es_dout_tvalid_u)?es_dout_tdata_u[63:32]: 
                      (mult_op || multu_op        )?es_alu_lo_result:
                      0;

reg div_en; //divid and unsigned divid enable

always @(posedge clk ) begin
    if (reset) begin
       div_en<=1;
    end
    else if (div_op||divu_op) begin
        div_en <=0;
    end
    else begin
        div_en <=1;
    end
end

always @(posedge clk ) begin
    if (reset) begin
        es_dividend_tvalid_r <=0;
        es_divisor_tvalid_r  <=0;  
    end
    else if (div_op &&div_en) begin
        es_dividend_tvalid_r <=1;
        es_divisor_tvalid_r  <=1;
    end
    
    else if (es_divisor_tready && es_dividend_tready) begin
        es_dividend_tvalid_r <=0;
        es_divisor_tvalid_r  <=0;
    end
    
end

always @(posedge clk ) begin
    if (reset) begin
        es_dividend_tvalid_u_r <=0;
        es_divisor_tvalid_u_r  <=0;  
    end
    else if (divu_op &&div_en) begin
        es_dividend_tvalid_u_r <=1;
        es_divisor_tvalid_u_r  <=1;
    end
    else if (es_divisor_tready_u && es_dividend_tready_u) begin
        es_dividend_tvalid_u_r <=0;
        es_divisor_tvalid_u_r  <=0;
    end
    
end


//write or read hi/lo 
assign hi_wdata = ((mult_op||multu_op||div_op||divu_op)&dest_is_hi)?es_hi_result:es_rs_value;
assign lo_wdata = ((mult_op||multu_op||div_op||divu_op)&dest_is_lo)?es_lo_result:es_rs_value;
assign es_hi_we = (dest_is_hi || (div_op&&(es_dout_tvalid_u || es_dout_tvalid )))&&((es_exc_type==4'd0) 
                && (ms_exc_type==4'd0) && (ws_exc_type==4'd0)) && eret_flush==0 && ms_eret==0 && es_to_ms_valid;
assign es_lo_we = (dest_is_lo || (div_op&&(es_dout_tvalid_u || es_dout_tvalid )))&&((es_exc_type==4'd0) 
                && (ms_exc_type==4'd0) && (ws_exc_type==4'd0)) && eret_flush==0 && ms_eret==0 && es_to_ms_valid;
assign es_result = es_res_from_hi ? hi_rdata:
                   es_res_from_lo ? lo_rdata:
                   es_mtc0_we     ? es_rt_value:
                   es_alu_result;

//Write strb

assign write_strb =     (es_store_type==`SWL_TYPE&&es_vaddr[1:0]==2'b00)?4'b0001:
                        (es_store_type==`SWL_TYPE&&es_vaddr[1:0]==2'b01)?4'b0011:
                        (es_store_type==`SWL_TYPE&&es_vaddr[1:0]==2'b10)?4'b0111:
                        (es_store_type==`SWL_TYPE&&es_vaddr[1:0]==2'b11)?4'b1111:
                        (es_store_type==`SWR_TYPE&&es_vaddr[1:0]==2'b00)?4'b1111:
                        (es_store_type==`SWR_TYPE&&es_vaddr[1:0]==2'b01)?4'b1110:
                        (es_store_type==`SWR_TYPE&&es_vaddr[1:0]==2'b10)?4'b1100:
                        (es_store_type==`SWR_TYPE&&es_vaddr[1:0]==2'b11)?4'b1000:
                        (es_store_type==`SB_TYPE &&es_vaddr[1:0]==2'b00)?4'b0001:
                        (es_store_type==`SB_TYPE &&es_vaddr[1:0]==2'b01)?4'b0010:
                        (es_store_type==`SB_TYPE &&es_vaddr[1:0]==2'b10)?4'b0100:
                        (es_store_type==`SB_TYPE &&es_vaddr[1:0]==2'b11)?4'b1000:
                        (es_store_type==`SH_TYPE &&es_vaddr[1]==1'b0)?4'b0011:
                        (es_store_type==`SH_TYPE &&es_vaddr[1]==1'b1)?4'b1100:
                        4'hf;

 assign store_data = (es_store_type==`SB_TYPE) ? {4{es_rt_value[7:0]}}  : 
                     (es_store_type==`SH_TYPE) ? {2{es_rt_value[15:0]}} :
                     (es_store_type==`SWL_TYPE&&es_vaddr[1:0]==2'b00)?{24'b0,es_rt_value[31:24]}:
                     (es_store_type==`SWL_TYPE&&es_vaddr[1:0]==2'b01)?{16'b0,es_rt_value[31:16]}:
                     (es_store_type==`SWL_TYPE&&es_vaddr[1:0]==2'b10)?{8'b0 ,es_rt_value[31:8]}:
                     (es_store_type==`SWL_TYPE&&es_vaddr[1:0]==2'b11)?es_rt_value:
                     (es_store_type==`SWR_TYPE&&es_vaddr[1:0]==2'b00)?es_rt_value:
                     (es_store_type==`SWR_TYPE&&es_vaddr[1:0]==2'b01)?{es_rt_value[23:0],8'b0 }:
                     (es_store_type==`SWR_TYPE&&es_vaddr[1:0]==2'b10)?{es_rt_value[15:0],16'b0}:
                     (es_store_type==`SWR_TYPE&&es_vaddr[1:0]==2'b11)?{es_rt_value[ 7:0],24'b0}:
                     es_rt_value;
alu u_alu(
    .alu_op         (es_alu_op    ),
    .alu_src1       (es_alu_src1  ),
    .alu_src2       (es_alu_src2  ),
    .alu_result     (es_alu_result),
    .alu_hi_result  (es_alu_hi_result),
    .alu_lo_result  (es_alu_lo_result),
    .alu_overflow   (es_alu_overflow)
    );

HILO_regs u_HILO_regs(
    .clk        (clk),
    .rd_hi      (hi_rdata),
    .rd_lo      (lo_rdata),
    .hi_we      (es_hi_we),
    .lo_we      (es_lo_we),
    .wd_hi      (hi_wdata),
    .wd_lo      (lo_wdata)
    );

mydiv u_mydiv(
    .aclk                   (clk),
    .s_axis_divisor_tdata   (es_divisor_tdata),
    .s_axis_divisor_tready  (es_divisor_tready),
    .s_axis_divisor_tvalid  (es_divisor_tvalid),
    .s_axis_dividend_tdata  (es_dividend_tdata),
    .s_axis_dividend_tready (es_dividend_tready),
    .s_axis_dividend_tvalid (es_dividend_tvalid),
    .m_axis_dout_tdata      (es_dout_tdata),
    .m_axis_dout_tvalid     (es_dout_tvalid)
    );

mydivu u_mydivu(
    .aclk                   (clk),
    .s_axis_divisor_tdata   (es_divisor_tdata_u),
    .s_axis_divisor_tready  (es_divisor_tready_u),
    .s_axis_divisor_tvalid  (es_divisor_tvalid_u),
    .s_axis_dividend_tdata  (es_dividend_tdata_u),
    .s_axis_dividend_tready (es_dividend_tready_u),
    .s_axis_dividend_tvalid (es_dividend_tvalid_u),
    .m_axis_dout_tdata      (es_dout_tdata_u),
    .m_axis_dout_tvalid     (es_dout_tvalid_u)
    );

// assign data_sram_en    = ds_to_es_valid && es_allowin ;
always @(posedge clk) begin
    if (reset) begin
        data_sram_en <= 1'b0;
    end
    else if (ms_allowin && (es_load_op || es_mem_we) && !ws_ex && !eret_flush ) begin
        data_sram_en <= 1'b1;
    end
    else if (data_sram_en&&data_addr_ok) begin
        data_sram_en <= 1'b0;
    end
end



// reg [3:0] data_addr_cnt;
// reg [3:0] data_data_cnt;
// always @(posedge clk) begin
//     if (reset)
//     begin
//         count <= 2'd0;
//     end
//     else
//     begin
//         count <= count + (data_sram_en&&data_addr_ok)
//                        - ((count!=2'd0)&&data_data_ok);
//     end
// end

// always @(posedge clk ) begin
//     if (reset)
//     begin
//         data_addr_cnt <= 4'd0;
//     end
//     else if (data_sram_en&&data_addr_ok)
//     begin
//         data_addr_cnt <= data_addr_cnt==4'd4 ? 4'd0 : data_addr_cnt + 1'b1;
//     end
// end

// always @(posedge clk) begin
//     if (reset)
//     begin
//         data_data_cnt <= 4'd0;
//     end
//     else if ((count!=2'd0)&&data_data_ok)
//     begin
//         data_data_cnt <= data_data_cnt==4'd4 ? 4'd0 : data_data_cnt + 1'b1;
//     end
// end

assign data_sram_wen   = es_mem_we && es_valid && (es_exc_type==4'd0) && (ms_exc_type==4'd0) 
                        && (ws_exc_type==4'd0) && ms_eret==0 && eret_flush==0 ? 1'b1 : 1'b0;
// always @(posedge clk) begin
//   if (reset) begin
//     data_sram_wen <= 0;
//   end
//   else if (es_mem_we && es_valid && (es_exc_type==4'd0) && (ms_exc_type==4'd0)&& (ws_exc_type==4'd0) && ms_eret==0 && eret_flush==0) begin
//     data_sram_wen <= 1;
//   end
//   else if (data_sram_wen && data_addr_ok) begin
//     data_sram_wen <= 0;
//   end
// end
assign data_sram_size  = (es_store_type==`SB_TYPE)?   2'b00:
                         (es_store_type==`SH_TYPE)?   2'b01:
                         (es_load_type ==`LB_TYPE)?   2'b00:
                         (es_load_type ==`LBU_TYPE)?  2'b00:
                         (es_load_type ==`LH_TYPE)?   2'b01:
                         (es_load_type ==`LHU_TYPE)?  2'b01:
                         (es_load_type ==`LWL_TYPE && es_vaddr[1:0]==2'd0)?  2'b00:
                         (es_load_type ==`LWL_TYPE && es_vaddr[1:0]==2'd1)?  2'b01:
                         (es_load_type ==`LWL_TYPE && es_vaddr[1:0]==2'd2)?  2'b10:
                         (es_load_type ==`LWL_TYPE && es_vaddr[1:0]==2'd3)?  2'b10:
                         (es_load_type ==`LWR_TYPE && es_vaddr[1:0]==2'd0)?  2'b10:
                         (es_load_type ==`LWR_TYPE && es_vaddr[1:0]==2'd1)?  2'b10:
                         (es_load_type ==`LWR_TYPE && es_vaddr[1:0]==2'd2)?  2'b01:
                         (es_load_type ==`LWR_TYPE && es_vaddr[1:0]==2'd3)?  2'b00:
                         (es_store_type ==`SWL_TYPE && es_vaddr[1:0]==2'd0)?  2'b00:
                         (es_store_type ==`SWL_TYPE && es_vaddr[1:0]==2'd1)?  2'b01:
                         (es_store_type ==`SWL_TYPE && es_vaddr[1:0]==2'd2)?  2'b10:
                         (es_store_type ==`SWL_TYPE && es_vaddr[1:0]==2'd3)?  2'b10:
                         (es_store_type ==`SWR_TYPE && es_vaddr[1:0]==2'd0)?  2'b10:
                         (es_store_type ==`SWR_TYPE && es_vaddr[1:0]==2'd1)?  2'b10:
                         (es_store_type ==`SWR_TYPE && es_vaddr[1:0]==2'd2)?  2'b01:
                         (es_store_type ==`SWR_TYPE && es_vaddr[1:0]==2'd3)?  2'b00:
                         2'b10;

// assign data_sram_size = (write_strb==4'd1||write_strb==4'd2||write_strb==4'd4||write_strb==4'd8)? 2'b00:
//                    (write_strb==4'b1100||write_strb==4'b0011)? 2'b01:
//                    (write_strb==4'b1110||write_strb==4'b0111)? 2'b10:
//                    2'b10;
assign data_sram_addr  = es_alu_result;
assign data_sram_wdata = store_data;


assign es_vaddr = es_alu_result;





endmodule
