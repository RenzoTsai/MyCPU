`include "mycpu.h"

module if_stage(
    input                          clk            ,
    input                          reset          ,
    //allwoin
    input                          ds_allowin     ,
    //brbus
    input  [`BR_BUS_WD-1       :0] br_bus         ,

    //to ds
    output                         fs_to_ds_valid ,
    output [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus   ,
    input  [`WS_TO_FS_BUS_WD -1:0] ws_to_fs_bus   ,
    // inst sram interface
    output        inst_sram_en   ,
    output [ 3:0] inst_sram_wen  ,
    output [31:0] inst_sram_addr ,
    output [31:0] inst_sram_wdata,
    input  [31:0] inst_sram_rdata
);

reg         fs_valid;
wire        fs_ready_go;
wire        fs_allowin;
wire        to_fs_valid;

wire [31:0] seq_pc;
wire [31:0] nextpc;


wire         br_taken;
wire [ 31:0] br_target;
assign {br_taken,br_target} = br_bus;

wire  ws_ex;
wire  eret_flush;
wire [31:0] cp0_epc;

assign {ws_ex,eret_flush,cp0_epc} = ws_to_fs_bus;

wire [31:0] fs_inst;
reg  [31:0] fs_pc;
wire [ 3:0] fs_exc_type;

assign fs_exc_type = (fs_pc[1:0]!=2'd0)?`ADEL_IF:0;
assign fs_to_ds_bus = {
                       fs_exc_type,
                       fs_inst ,
                       fs_pc   };

// pre-IF stage
assign to_fs_valid  = ~reset;
assign seq_pc       = fs_pc + 3'h4;

assign nextpc       = br_taken ? br_target :              
                                 seq_pc; 




// IF stage
assign fs_ready_go    = 1'b1;
assign fs_allowin     = !fs_valid || fs_ready_go && ds_allowin;
assign fs_to_ds_valid =  fs_valid && fs_ready_go;



always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    else if (ws_ex || eret_flush)      begin
        fs_valid <= 1'b0;
    end
    else if (fs_allowin) begin
        fs_valid <= to_fs_valid;
    end
end

always @(posedge clk) begin
    if (reset) begin
        fs_pc <= 32'hbfbffffc;  //trick: to make nextpc be 0xbfc00000 during reset 
    end
    else if (to_fs_valid && ws_ex  )  begin
        fs_pc <= 32'hbfc0037c;
    end
    else if (to_fs_valid && eret_flush) begin
        fs_pc <= cp0_epc-4;
    end
    else if (to_fs_valid && fs_allowin) begin
        fs_pc <= nextpc;
    end
end



assign inst_sram_en    = to_fs_valid && fs_allowin;
assign inst_sram_wen   = 4'h0;
assign inst_sram_addr  = nextpc;
assign inst_sram_wdata = 32'b0;

assign fs_inst         = inst_sram_rdata;


endmodule
