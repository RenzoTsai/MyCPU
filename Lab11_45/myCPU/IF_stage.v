`include "mycpu.h"

module if_stage(
    input                          clk            ,
    input                          reset          ,
    //allwoin
    input                          ds_allowin     ,
    //brbus
    input  [`BR_BUS_WD-1       :0] br_bus         ,
    input                          es_allowin     ,
    //to ds
    output                         fs_to_ds_valid ,
    output [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus   ,
    input  [`WS_TO_FS_BUS_WD -1:0] ws_to_fs_bus   ,
    // inst sram interface
    output reg    inst_sram_en   ,
    output        inst_sram_wen  ,
    output [ 1:0] inst_sram_size,
    output [31:0] inst_sram_addr ,
    output [31:0] inst_sram_wdata,
    input  [31:0] inst_sram_rdata,
    input         inst_addr_ok,
    input         inst_data_ok
);

reg         fs_valid;
wire        fs_ready_go;
wire        fs_allowin;
wire        to_fs_valid;

wire [31:0] seq_pc;
wire [31:0] nextpc;

wire         ds_to_es_valid;
wire         br_taken;
wire [ 31:0] br_target;
assign {ds_to_es_valid,br_taken,br_target} = br_bus;

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
reg pre_fs_valid;
reg pre_fs_ready_go;
wire pre_fs_allowin;

assign to_fs_valid  = ~reset&&inst_addr_ok;
// assign pre_fs_allowin = 1;
// //assign pre_fs_ready_go = (reset)?1:inst_addr_ok;

// always @(posedge clk) begin
//     if (reset) begin
//         pre_fs_valid <= 1'b0;
//     end
//     else if (ws_ex || eret_flush)      begin
//         pre_fs_valid <= 1'b0;
//     end
//     else if (pre_fs_allowin) begin
//         pre_fs_valid <= 1;
//     end
// end

// always @(posedge clk) begin
//     if (reset) begin
//         pre_fs_ready_go <= 1'b1;
//     end
//     else if(inst_addr_ok)begin
//         pre_fs_ready_go <= 1'b1;
//     end
//     else if (pre_fs_ready_go) begin
//         pre_fs_ready_go <= 1'b0;
//     end
// end

assign seq_pc       = fs_pc + 3'h4;

assign nextpc       =              
                                 seq_pc; 




// IF stage
assign fs_ready_go    =fs_inst_valid|| inst_data_ok;
assign fs_allowin     = !fs_valid || fs_ready_go && ds_allowin;
assign fs_to_ds_valid =  fs_valid && fs_ready_go;
reg fs_inst_valid;
always@(posedge clk)begin
    if(reset)begin
        fs_inst_valid <= 0;
    end
    else if(eret_flush || ws_ex)begin
        fs_inst_valid <= 0;
    end
    else if(fs_valid && inst_data_ok && !ds_allowin)begin
        fs_inst_valid <= 1;
    end
    else if(fs_to_ds_valid && ds_allowin)begin
        fs_inst_valid <= 0;
    end
end

always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    else if (ws_ex || eret_flush)      begin
        fs_valid <= 1'b0;
    end
    else if ( fs_allowin) begin
        fs_valid <= to_fs_valid;
    end


    if (reset) begin
        fs_pc <= 32'hbfbffffc;  //trick: to make nextpc be 0xbfc00000 during reset 
    end
    // else if (to_fs_valid && ws_ex  )  begin
    //     fs_pc <= 32'hbfc0037c;
    // end
    // else if (to_fs_valid && eret_flush) begin
    //     fs_pc <= cp0_epc-4;
    // end
    else if (to_fs_valid && fs_allowin) begin
        fs_pc <= true_npc;
    end
end



reg [1:0]count;
always @(posedge clk) begin
    if (reset) begin
        count <= 0;
    end
    else begin
        count <= count + inst_addr_ok -inst_data_ok;
    end
end
// assign inst_sram_en    = to_fs_valid && fs_allowin ;
always @(posedge clk) begin
    if (reset) begin
        inst_sram_en <= 1'b0;
    end
    else if (ws_ex || eret_flush) begin
        inst_sram_en <= 1'b1;
    end
    // else if (fs_allowin) begin
    //     inst_sram_en <= 1'b1;
    // end
    else if (inst_sram_en&&inst_addr_ok) begin
        inst_sram_en <= 1'b0;
    end    
    else if (fs_allowin) begin
        inst_sram_en <= 1'b1;
    end
end
// assign inst_sram_en = fs_allowin&&count==0;

    reg        br_taken_r;
    reg [31:0] br_target_r;
    wire[31:0] true_npc;
    assign true_npc =   ws_ex_r    ? 32'hbfc00380:
                        eret_flush_r ? cp0_epc:
                        br_taken_r && ds_to_es_valid ? br_target_r: 
                        br_taken_r && !ds_to_es_valid?  true_npc_r :nextpc;

    reg [31:0]true_npc_r;
    always @(posedge clk) begin
        if (reset) begin
            true_npc_r <= nextpc;
        end
        else if (inst_sram_en && inst_addr_ok) begin
            true_npc_r <= true_npc;
        end
        else if(br_taken) begin
            true_npc_r <= true_npc;
        end
    end
    always @(posedge clk)
    begin
        if(reset)
        begin
            br_taken_r <= 1'b0;
        end
        else if (ws_ex||eret_flush) begin
            br_taken_r <= 1'b0;
        end
        else if (br_taken) begin
            br_taken_r <= 1'b1;
        end
        else if(br_taken_r==1 && to_fs_valid && fs_allowin && ds_to_es_valid)
        begin
            br_taken_r <= 1'b0;
        end
        if(br_taken)
        begin
            br_target_r <= br_target;
        end
    end

    reg       ws_ex_r;
    always @(posedge clk) begin
        if (reset) begin
            ws_ex_r <= 1'b0;
        end
        else if (ws_ex) begin
            ws_ex_r <= 1'b1;
        end
        else if (to_fs_valid && fs_allowin) begin
            ws_ex_r <= 1'b0;
        end
    end

    reg     eret_flush_r;
    always @(posedge clk) begin
        if (reset) begin
            eret_flush_r <= 1'b0;
        end
        else if (eret_flush) begin
            eret_flush_r <= 1'b1;
        end
        else if (to_fs_valid && fs_allowin) begin
            eret_flush_r <= 1'b0;
        end
    end
assign inst_sram_wen   = 1'h0;
assign inst_sram_size  = 2'b10;
assign inst_sram_addr  = (inst_sram_en&&inst_addr_ok)?true_npc:0;
// always @(posedge clk) begin
//     if (reset) begin
//         inst_sram_addr <= 0;
//     end
//     else if (inst_sram_en&&inst_addr_ok) begin
//         inst_sram_addr <= nextpc;
//     end
// end

assign inst_sram_wdata = 32'b0;
reg [31:0] fs_inst_r;
assign fs_inst = fs_inst_valid? fs_inst_r: inst_sram_rdata;

always@(posedge clk)begin
    if(inst_data_ok && fs_valid)begin
        fs_inst_r <= inst_sram_rdata;
    end
end
endmodule