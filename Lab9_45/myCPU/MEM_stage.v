`include "mycpu.h"

module mem_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ws_allowin    ,
    output                         ms_allowin    ,
    //from es
    input                          es_to_ms_valid,
    input  [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    //to ws
    output                         ms_to_ws_valid,
    output [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus  ,
    //from data-sram
    input  [31                 :0] data_sram_rdata,
    output out_ms_valid
);


reg         ms_valid;
wire        ms_ready_go;
assign out_ms_valid =ms_valid;

reg [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus_r;
wire        ms_res_from_mem;
wire        ms_gr_we;
wire [ 4:0] ms_dest;
wire [31:0] ms_alu_result;
wire [31:0] ms_pc;
wire [ 1:0] ms_vaddr_2;
wire [ 2:0] ms_load_type;
wire [31:0] ms_rt_value;

wire [ 7:0] ms_rd_sel;
wire        ms_res_from_cp0;
wire        ms_mtc0_we;
wire [ 2:0] ms_exc_type;
wire        ms_eret;
wire        ms_bd;

assign {ms_bd          ,  //122:122
        ms_eret        ,  //121:121
        ms_exc_type    ,  //120:118
        ms_rd_sel      ,  //117:110
        ms_res_from_cp0,  //109:109
        ms_mtc0_we     ,  //108:108
        ms_rt_value    ,  //107:76
        ms_vaddr_2     ,  //75:74
        ms_load_type   ,  //73:71
        ms_res_from_mem,  //70:70
        ms_gr_we       ,  //69:69
        ms_dest        ,  //68:64
        ms_alu_result  ,  //63:32
        ms_pc             //31:0
       } = es_to_ms_bus_r;

wire [31:0] mem_result;
wire [31:0] ms_final_result;

assign ms_to_ws_bus = {ms_bd          ,  //84:84
                       ms_eret        ,  //83:83
                       ms_exc_type    ,  //82:80
                       ms_rd_sel      ,  //79:72
                       ms_res_from_cp0,  //71:71
                       ms_mtc0_we     ,  //70:70
                       ms_gr_we       ,  //69:69
                       ms_dest        ,  //68:64
                       ms_final_result,  //63:32
                       ms_pc             //31:0
                      };

assign ms_ready_go    = 1'b1;
assign ms_allowin     = !ms_valid || ms_ready_go && ws_allowin;
assign ms_to_ws_valid = ms_valid && ms_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ms_valid <= 1'b0;
    end
    else if (ms_allowin) begin
        ms_valid <= es_to_ms_valid;
    end

    if (es_to_ms_valid && ms_allowin) begin
        es_to_ms_bus_r  <= es_to_ms_bus;
    end
end

assign mem_result =   (ms_load_type==`LB_TYPE &&ms_vaddr_2[1:0]==2'b00)?{{24{data_sram_rdata[ 7]}},data_sram_rdata[7:0]}:
                      (ms_load_type==`LB_TYPE &&ms_vaddr_2[1:0]==2'b01)?{{24{data_sram_rdata[15]}},data_sram_rdata[15:8]}:
                      (ms_load_type==`LB_TYPE &&ms_vaddr_2[1:0]==2'b10)?{{24{data_sram_rdata[23]}},data_sram_rdata[23:16]}:
                      (ms_load_type==`LB_TYPE &&ms_vaddr_2[1:0]==2'b11)?{{24{data_sram_rdata[31]}},data_sram_rdata[31:24]}:
                      (ms_load_type==`LBU_TYPE&&ms_vaddr_2[1:0]==2'b00)?{24'b0,data_sram_rdata[ 7:0]}:
                      (ms_load_type==`LBU_TYPE&&ms_vaddr_2[1:0]==2'b01)?{24'b0,data_sram_rdata[15:8]}:
                      (ms_load_type==`LBU_TYPE&&ms_vaddr_2[1:0]==2'b10)?{24'b0,data_sram_rdata[23:16]}:
                      (ms_load_type==`LBU_TYPE&&ms_vaddr_2[1:0]==2'b11)?{24'b0,data_sram_rdata[31:24]}:
                      (ms_load_type==`LH_TYPE &&ms_vaddr_2[1]==2'b0)   ?{{16{data_sram_rdata[15]}},data_sram_rdata[15:0]}:
                      (ms_load_type==`LH_TYPE &&ms_vaddr_2[1]==2'b1)   ?{{16{data_sram_rdata[31]}},data_sram_rdata[31:16]}:
                      (ms_load_type==`LHU_TYPE&&ms_vaddr_2[1]==2'b0)   ?{16'b0,data_sram_rdata[15: 0]}:
                      (ms_load_type==`LHU_TYPE&&ms_vaddr_2[1]==2'b1)   ?{16'b0,data_sram_rdata[31:16]}:
                      (ms_load_type==`LWL_TYPE &&ms_vaddr_2[1:0]==2'b00)?{data_sram_rdata[7:0],ms_rt_value[23:0]}:
                      (ms_load_type==`LWL_TYPE &&ms_vaddr_2[1:0]==2'b01)?{data_sram_rdata[15:0],ms_rt_value[15:0]}:
                      (ms_load_type==`LWL_TYPE &&ms_vaddr_2[1:0]==2'b10)?{data_sram_rdata[23:0],ms_rt_value[7:0]}:
                      (ms_load_type==`LWL_TYPE &&ms_vaddr_2[1:0]==2'b11)? data_sram_rdata[31:0]:
                      (ms_load_type==`LWR_TYPE &&ms_vaddr_2[1:0]==2'b00)? data_sram_rdata[31:0]:
                      (ms_load_type==`LWR_TYPE &&ms_vaddr_2[1:0]==2'b01)?{ms_rt_value[31:24], data_sram_rdata[31:8]}:
                      (ms_load_type==`LWR_TYPE &&ms_vaddr_2[1:0]==2'b10)?{ms_rt_value[31:16], data_sram_rdata[31:16]}:
                      (ms_load_type==`LWR_TYPE &&ms_vaddr_2[1:0]==2'b11)?{ms_rt_value[31:8], data_sram_rdata[31:24]}:
                      data_sram_rdata;

assign ms_final_result = ms_res_from_mem ? mem_result
                                         : ms_alu_result;

wire AdEL;
assign AdEL = (ms_pc[1:0]!=2'b00)?1:
              (ms_load_type=`LW_TYPE&&ms_vaddr_2[1:0]!=2'b00)?1:
              (ms_load_type==`LH_TYPE&&ms_vaddr_2[0]!=1'b0)?1:
              (ms_load_type==`LHU_TYPE&&ms_vaddr_2[0]!=1'b0)?1:
              0;

endmodule
