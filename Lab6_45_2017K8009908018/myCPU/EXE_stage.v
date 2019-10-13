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
    output        data_sram_en   ,
    output [ 3:0] data_sram_wen  ,
    output [31:0] data_sram_addr ,
    output [31:0] data_sram_wdata,
    output out_es_valid
);



reg         es_valid      ;
wire        es_ready_go   ;
assign out_es_valid=es_valid ;

reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;
wire [11:0] es_alu_op     ;
wire        es_load_op    ;
wire        es_src1_is_sa ;  
wire        es_src1_is_pc ;
wire        es_src2_is_imm; 
wire        es_src2_is_8  ;
wire        es_gr_we      ;
wire        es_mem_we     ;
wire [ 4:0] es_dest       ;
wire [15:0] es_imm        ;
wire [31:0] es_rs_value   ;
wire [31:0] es_rt_value   ;
wire [31:0] es_pc         ;

wire es_hi_we;
wire es_lo_we;
wire dest_is_hi;
wire dest_is_lo;
wire es_res_from_hi;
wire es_res_from_lo;
wire [31:0]es_result;

assign {es_res_from_hi ,  //143:143
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

wire [31:0] es_alu_src1   ;
wire [31:0] es_alu_src2   ;
wire [31:0] es_alu_result ;
wire [31:0] es_alu_hi_result ;
wire [31:0] es_alu_lo_result ;
wire [31:0] hi_rdata;
wire [31:0] lo_rdata;
wire [31:0] hi_wdata;
wire [31:0] lo_wdata;


wire        es_res_from_mem;

assign es_res_from_mem = es_load_op;
assign es_to_ms_bus = {es_res_from_mem,  //70:70
                       es_gr_we       ,  //69:69
                       es_dest        ,  //68:64
                       es_result  ,      //63:32  -> including: es_alu_result & (hi/lo)
                       es_pc             //31:0
                      };

assign es_ready_go    = 1'b1;
assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid =  es_valid && es_ready_go;
always @(posedge clk) begin
    if (reset) begin
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
                     es_src2_is_8   ? 32'd8 :
                                      es_rt_value;
//hi/lo write or read
assign hi_wdata = (es_alu_op[12]&es_alu_op[13]&es_alu_op[14]&es_alu_op[15]&dest_is_hi)es_alu_hi_result:es_rs_value;
assign lo_wdata = (es_alu_op[12]&es_alu_op[13]&es_alu_op[14]&es_alu_op[15]&dest_is_lo)es_alu_hi_result:es_rs_value;
assign es_hi_we = dest_is_hi ;
assign es_lo_we = dest_is_lo ;
assign es_result = res_from_hi ? hi_rdata:
                   res_from_lo ? lo_rdata:
                   es_alu_result;

alu u_alu(
    .alu_op         (es_alu_op    ),
    .alu_src1       (es_alu_src1  ),
    .alu_src2       (es_alu_src2  ),
    .alu_result     (es_alu_result),
    .alu_hi_result  (es_alu_hi_result),
    .alu_lo_result  (es_alu_lo_result)
    );

cp0_regs u_cp0_regs(
    .clk        (clk),
    .rd_hi      (hi_rdata),
    .rd_lo      (lo_rdata),
    .hi_we      (es_hi_we),
    .lo_we      (es_lo_we),
    .wd_hi      (hi_wdata),
    .wd_lo      (lo_wdata)
    );

assign data_sram_en    = 1'b1;
assign data_sram_wen   = es_mem_we&&es_valid ? 4'hf : 4'h0;
assign data_sram_addr  = es_alu_result;
assign data_sram_wdata = es_rt_value;

endmodule
