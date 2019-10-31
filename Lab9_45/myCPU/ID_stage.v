`include "mycpu.h"

module id_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          es_allowin    ,
    output                         ds_allowin    ,
    //from fs
    input                          fs_to_ds_valid,
    input                          es_to_ms_valid,
    input                          ms_to_ws_valid,
    input  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus  ,
    //to es

    input  [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus,
    input  [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus,

    output                         ds_to_es_valid,
    output [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to fs
    output [`BR_BUS_WD       -1:0] br_bus        ,
    //to rf: for write back
    input  [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus,
    input out_es_valid,
    input out_ms_valid
);

wire hazard;


reg         ds_valid   ;

wire        ds_ready_go;

wire [31                 :0] fs_pc;
reg  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus_r;
assign fs_pc = fs_to_ds_bus[31:0];

wire [31:0] ds_inst;
wire [31:0] ds_pc  ;
assign {ds_inst,
        ds_pc  } = fs_to_ds_bus_r;

wire        rf_we   ;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;
wire [31:0] cp0_epc;
wire        ws_mtc0_we;
wire        ws_gr_we;
wire        ws_valid;

assign {ws_mtc0_we ,  //72:72
        cp0_epc ,  //71:40
        ws_gr_we,  //39:39
        ws_valid,  //38:38 
        rf_we   ,  //37:37
        rf_waddr,  //36:32
        rf_wdata   //31:0
       } = ws_to_rf_bus;

wire        br_taken;
wire [31:0] br_target;

wire [15:0] alu_op;
wire        load_op;
wire        src1_is_sa;
wire        src1_is_pc;
wire        src2_is_imm;
wire        src2_is_uimm;
wire        src2_is_8;
wire        res_from_mem;
wire        res_from_hi;
wire        res_from_lo;
wire        gr_we;
wire        mem_we;
wire [ 4:0] dest;
wire [15:0] imm;
wire [31:0] rs_value;
wire [31:0] rt_value;

wire [ 5:0] op;
wire [ 4:0] rs;
wire [ 4:0] rt;
wire [ 4:0] rd;
wire [ 4:0] sa;
wire [ 5:0] func;
wire [25:0] jidx;
wire [63:0] op_d;
wire [31:0] rs_d;
wire [31:0] rt_d;
wire [31:0] rd_d;
wire [31:0] sa_d;
wire [63:0] func_d;

wire        inst_addu;
wire        inst_subu;
wire        inst_slt;
wire        inst_sltu;
wire        inst_and;
wire        inst_or;
wire        inst_xor;
wire        inst_nor;
wire        inst_sll;
wire        inst_srl;
wire        inst_sra;
wire        inst_addiu;
wire        inst_lui;
wire        inst_lw;
wire        inst_sw;
wire        inst_beq;
wire        inst_bne;
wire        inst_jal;
wire        inst_jr;

wire        inst_add;
wire        inst_addi;
wire        inst_sub;
wire        inst_slti;
wire        inst_sltiu;
wire        inst_andi;
wire        inst_ori;
wire        inst_xori;
wire        inst_sllv;
wire        inst_srav;
wire        inst_srlv;
wire        inst_mult;
wire        inst_multu;
wire        inst_div;
wire        inst_divu;
wire        inst_mfhi;
wire        inst_mflo;
wire        inst_mthi;
wire        inst_mtlo;

wire        inst_bgez;
wire        inst_bgtz;
wire        inst_blez;
wire        inst_bltz;
wire        inst_j;
wire        inst_bltzal;
wire        inst_bgezal;
wire        inst_jalr;
wire        inst_lb;
wire        inst_lbu;
wire        inst_lh;
wire        inst_lhu;
wire        inst_lwl;
wire        inst_lwr;
wire        inst_sb;
wire        inst_sh;
wire        inst_swl;
wire        inst_swr;

wire        inst_eret;
wire        inst_mfc0;
wire        inst_mtc0;
wire        inst_syscall;
wire        inst_break;

wire        dst_is_r31;  
wire        dst_is_rt;
wire        dst_is_hi;
wire        dst_is_lo;   

wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;

wire        rs_eq_rt;
wire        rs_ge_zero;
wire        rs_gt_zero;
wire        rs_le_zero;
wire        rs_lt_zero;

wire [ 2:0] load_type;
wire [ 1:0] vaddr_2;
wire [ 2:0] store_type;
wire [ 2:0] exc_type;

wire [ 7:0] rd_sel;
wire        res_from_cp0;
wire        mtc0_we;
wire        ds_eret;

reg  bd_valid;
wire ds_bd;

assign rd_sel  = {rd,ds_inst[2:0]} ;
assign mtc0_we = inst_mtc0;

assign exc_type = (inst_syscall)?`SYSCALL:
                  (inst_break)?`BREAK:
                  0;

assign ds_eret  = inst_eret ;


assign br_bus       = {inst_syscall,br_taken,br_target};

assign ds_to_es_bus = {ds_bd       ,  //167:167
                       ds_eret     ,  //166:166
                       exc_type    ,  //165:163
                       rd_sel      ,  //162:155
                       res_from_cp0,  //154:154
                       mtc0_we     ,  //153:153
                       store_type  ,  //152:150
                       vaddr_2     ,  //149:148
                       load_type   ,  //147:145
                       src2_is_uimm,  //144:144
                       res_from_hi ,  //143:143
                       res_from_lo ,  //142:142
                       dst_is_hi   ,  //141:141
                       dst_is_lo   ,  //140:140
                       alu_op      ,  //139:124
                       load_op     ,  //123:123
                       src1_is_sa  ,  //122:122
                       src1_is_pc  ,  //121:121
                       src2_is_imm ,  //120:120
                       src2_is_8   ,  //119:119
                       gr_we       ,  //118:118
                       mem_we      ,  //117:117
                       dest        ,  //116:112
                       imm         ,  //111:96
                       rs_value    ,  //95 :64
                       rt_value    ,  //63 :32
                       ds_pc          //31 :0
                      };



assign ds_ready_go= (out_es_valid && es_to_ms_bus[70] && es_to_ms_bus[69])? 0 :
                    (out_es_valid &&es_to_ms_bus[109]&&(es_to_ms_bus[68:64]==rs||&es_to_ms_bus[68:64]==rt))?0:
                    (out_ms_valid &&ms_to_ws_bus[71]&&(ms_to_ws_bus[68:64]==rs||&ms_to_ws_bus[68:64]==rt))?0:
                    (out_es_valid &&es_to_ms_bus[108] && ds_eret)?0:
                    (out_ms_valid &&es_to_ms_bus[ 70] && ds_eret)?0:
                    (ws_valid && ws_mtc0_we && ds_eret)?0:
                    1;

assign ds_allowin     = (!ds_valid || ds_ready_go && es_allowin) ;
assign ds_to_es_valid = ds_valid && ds_ready_go;
always @(posedge clk) begin
    if(reset)begin
    ds_valid<=0;
    end
    else if(inst_syscall&& ds_allowin)begin
            ds_valid<=0;
    end
    else if (ds_allowin) begin
            ds_valid <= fs_to_ds_valid;
    end
    if (fs_to_ds_valid && ds_allowin) begin
        fs_to_ds_bus_r <= fs_to_ds_bus;
    end
end
 

assign op   = ds_inst[31:26];
assign rs   = ds_inst[25:21];
assign rt   = ds_inst[20:16];
assign rd   = ds_inst[15:11];
assign sa   = ds_inst[10: 6];
assign func = ds_inst[ 5: 0];
assign imm  = ds_inst[15: 0];
assign jidx = ds_inst[25: 0];

decoder_6_64 u_dec0(.in(op  ), .out(op_d  ));
decoder_6_64 u_dec1(.in(func), .out(func_d));
decoder_5_32 u_dec2(.in(rs  ), .out(rs_d  ));
decoder_5_32 u_dec3(.in(rt  ), .out(rt_d  ));
decoder_5_32 u_dec4(.in(rd  ), .out(rd_d  ));
decoder_5_32 u_dec5(.in(sa  ), .out(sa_d  ));

assign load_op=inst_lw | inst_lb | inst_lbu | inst_lh | inst_lhu | inst_lwl | inst_lwr;


assign load_type =  inst_lw  ? `LW_TYPE:
                    inst_lb  ? `LB_TYPE:
                    inst_lbu ? `LBU_TYPE:
                    inst_lh  ? `LH_TYPE:
                    inst_lhu ? `LHU_TYPE:
                    inst_lwl ? `LWL_TYPE:
                    inst_lwr ? `LWR_TYPE:
                    3'b000;

assign store_type = inst_sw  ? `SW_TYPE:
                    inst_sb  ? `SB_TYPE:
                    inst_sh  ? `SH_TYPE:
                    inst_swl ? `SWL_TYPE:
                    inst_swr ? `SWR_TYPE:
                    3'b000;

assign vaddr_2 = (load_op || mem_we) ? func[1:0]:2'b0;

assign inst_addu   = op_d[6'h00] & func_d[6'h21] & sa_d[5'h00];
assign inst_subu   = op_d[6'h00] & func_d[6'h23] & sa_d[5'h00];
assign inst_slt    = op_d[6'h00] & func_d[6'h2a] & sa_d[5'h00];
assign inst_sltu   = op_d[6'h00] & func_d[6'h2b] & sa_d[5'h00];
assign inst_and    = op_d[6'h00] & func_d[6'h24] & sa_d[5'h00];
assign inst_or     = op_d[6'h00] & func_d[6'h25] & sa_d[5'h00];
assign inst_xor    = op_d[6'h00] & func_d[6'h26] & sa_d[5'h00];
assign inst_nor    = op_d[6'h00] & func_d[6'h27] & sa_d[5'h00];
assign inst_sll    = op_d[6'h00] & func_d[6'h00] & rs_d[5'h00];
assign inst_srl    = op_d[6'h00] & func_d[6'h02] & rs_d[5'h00];
assign inst_sra    = op_d[6'h00] & func_d[6'h03] & rs_d[5'h00];
assign inst_addiu  = op_d[6'h09];
assign inst_lui    = op_d[6'h0f] & rs_d[5'h00];
assign inst_lw     = op_d[6'h23];
assign inst_sw     = op_d[6'h2b];
assign inst_beq    = op_d[6'h04];
assign inst_bne    = op_d[6'h05];
assign inst_jal    = op_d[6'h03];
assign inst_jr     = op_d[6'h00] & func_d[6'h08] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];

assign inst_add    = op_d[6'h00] & func_d[6'h20] & sa_d[5'h00];
assign inst_addi   = op_d[6'h08];
assign inst_sub    = op_d[6'h00] & func_d[6'h22] & sa_d[5'h00];
assign inst_slti   = op_d[6'h0a];
assign inst_sltiu  = op_d[6'h0b];
assign inst_andi   = op_d[6'h0c];
assign inst_ori    = op_d[6'h0d];
assign inst_xori   = op_d[6'h0e];
assign inst_sllv   = op_d[6'h00] & func_d[6'h04] & sa_d[5'h00];
assign inst_srav   = op_d[6'h00] & func_d[6'h07] & sa_d[5'h00];
assign inst_srlv   = op_d[6'h00] & func_d[6'h06] & sa_d[5'h00];
assign inst_mult   = op_d[6'h00] & func_d[6'h18] & sa_d[5'h00] & rd_d[5'h00];
assign inst_multu  = op_d[6'h00] & func_d[6'h19] & sa_d[5'h00] & rd_d[5'h00];
assign inst_div    = op_d[6'h00] & func_d[6'h1a] & sa_d[5'h00] & rd_d[5'h00];
assign inst_divu   = op_d[6'h00] & func_d[6'h1b] & sa_d[5'h00] & rd_d[5'h00];
assign inst_mfhi   = op_d[6'h00] & func_d[6'h10] & rs_d[5'h00] & rt_d[5'h00] & sa_d[5'h00];
assign inst_mflo   = op_d[6'h00] & func_d[6'h12] & rs_d[5'h00] & rt_d[5'h00] & sa_d[5'h00];
assign inst_mthi   = op_d[6'h00] & func_d[6'h11] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];
assign inst_mtlo   = op_d[6'h00] & func_d[6'h13] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];

assign inst_bgez   = op_d[6'h01] & rt_d[5'h01];
assign inst_bgtz   = op_d[6'h07] & rt_d[5'h00];
assign inst_blez   = op_d[6'h06] & rt_d[5'h00];
assign inst_bltz   = op_d[6'h01] & rt_d[5'h00];
assign inst_j      = op_d[6'h02];
assign inst_bltzal = op_d[6'h01] & rt_d[5'h10];
assign inst_bgezal = op_d[6'h01] & rt_d[5'h11];
assign inst_jalr   = op_d[6'h00] & func_d[6'h09] & rt_d[5'h00] & sa_d[5'h00];
assign inst_lb     = op_d[6'h20];
assign inst_lbu    = op_d[6'h24];
assign inst_lh     = op_d[6'h21];
assign inst_lhu    = op_d[6'h25];
assign inst_lwl    = op_d[6'h22];
assign inst_lwr    = op_d[6'h26];
assign inst_sb     = op_d[6'h28];
assign inst_sh     = op_d[6'h29];
assign inst_swl    = op_d[6'h2a];
assign inst_swr    = op_d[6'h2e];

assign inst_eret   = op_d[6'h10] & rs_d[5'h10] & func_d[6'h18] & rd_d[5'h00] & rt_d[5'h00] & sa_d[5'h00];
assign inst_mfc0   = op_d[6'h10] & rs_d[5'h00] & sa_d[5'h00] & (ds_inst[5:3]==0) ;
assign inst_mtc0   = op_d[6'h10] & rs_d[5'h04] & sa_d[5'h00] & (ds_inst[5:3]==0) ;
assign inst_syscall= op_d[6'h00] & func_d[6'h0c];

assign inst_break  = op_d[6'h00] & func_d[6'h0d];

assign alu_op[ 0] = inst_addu | inst_addiu | inst_lw | inst_sw  | inst_jal | inst_add | inst_addi | inst_bgezal | inst_bltzal | inst_jalr
                    | inst_lb | inst_lbu   | inst_lh | inst_lhu | inst_sb  | inst_sh  | inst_swl  | inst_swr    | inst_lwl		| inst_lwr ;
assign alu_op[ 1] = inst_subu | inst_sub;
assign alu_op[ 2] = inst_slt  | inst_slti;
assign alu_op[ 3] = inst_sltu | inst_sltiu;
assign alu_op[ 4] = inst_and  | inst_andi;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or   | inst_ori;
assign alu_op[ 7] = inst_xor  | inst_xori;
assign alu_op[ 8] = inst_sll  | inst_sllv;
assign alu_op[ 9] = inst_srl  | inst_srlv;
assign alu_op[10] = inst_sra  | inst_srav;
assign alu_op[11] = inst_lui;
assign alu_op[12] = inst_mult;
assign alu_op[13] = inst_multu;
assign alu_op[14] = inst_div;
assign alu_op[15] = inst_divu;


assign src1_is_sa   = inst_sll   | inst_srl    | inst_sra;
assign src1_is_pc   = inst_jal   | inst_bltzal | inst_bgezal | inst_jalr;
assign src2_is_imm  = inst_addiu | inst_lui | inst_lw | inst_sw  | inst_addi | inst_slti | inst_sltiu 
                      | inst_lb  | inst_lbu | inst_lh | inst_lhu | inst_sb   | inst_sh   | inst_swl  | inst_swr | inst_lwl | inst_lwr;
assign src2_is_uimm = inst_andi  | inst_ori | inst_xori;
assign src2_is_8    = inst_jal   | inst_bltzal | inst_bgezal | inst_jalr;
assign res_from_mem = inst_lw    | inst_lb  | inst_lbu | inst_lh | inst_lhu | inst_lwl | inst_lwr;
assign dst_is_r31   = inst_jal   | inst_bltzal | inst_bgezal;
assign dst_is_rt    = inst_addiu | inst_lui | inst_lw  | inst_addi | inst_slti | inst_sltiu | inst_andi | inst_ori 
                     | inst_xori | inst_lb  | inst_lbu | inst_lh   | inst_lhu  | inst_lwl   | inst_lwr  | inst_mfc0;
assign gr_we        = ~inst_sw & ~inst_beq & ~inst_bne & ~inst_jr & ~inst_sb & ~inst_sh & ~inst_swl & ~inst_swr & ~inst_bgez & ~inst_bgtz& ~inst_blez & ~inst_bltz & ~inst_j & ~inst_mtc0 &~inst_syscall &~inst_eret &~inst_break;
assign mem_we       = inst_sw    | inst_sb  | inst_sh    | inst_swl  | inst_swr;
assign dst_is_hi    = inst_mthi | inst_mult | inst_multu | inst_divu | inst_div;
assign dst_is_lo    = inst_mtlo | inst_mult | inst_multu | inst_divu | inst_div;
assign res_from_hi  = inst_mfhi;
assign res_from_lo  = inst_mflo;
assign res_from_cp0 = inst_mfc0;

assign dest         = dst_is_r31 ? 5'd31 :
                      dst_is_rt  ? rt    : 
                                   rd;


assign rf_raddr1 = rs;
assign rf_raddr2 = rt;




regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );


assign rs_value =  (rf_raddr1==es_to_ms_bus[68:64]&&es_to_ms_bus[69]&&es_to_ms_valid&&!es_to_ms_bus[70])?es_to_ms_bus[63:32]:
                   (rf_raddr1==ms_to_ws_bus[68:64]&&ms_to_ws_bus[69]&&ms_to_ws_valid)?ms_to_ws_bus[63:32]:
                   (rf_raddr1==rf_waddr && ws_gr_we && ws_valid)?rf_wdata:
                   rf_rdata1;
                   

assign rt_value =  (rf_raddr2==es_to_ms_bus[68:64]&&es_to_ms_bus[69]&&es_to_ms_valid&&!es_to_ms_bus[70])?es_to_ms_bus[63:32]:
                   (rf_raddr2==ms_to_ws_bus[68:64]&&ms_to_ws_bus[69]&&ms_to_ws_valid)?ms_to_ws_bus[63:32]:
                   (rf_raddr2==rf_waddr && ws_gr_we && ws_valid)?rf_wdata:
                   rf_rdata2;
                   


assign rs_eq_rt   = (rs_value == rt_value);
assign rs_ge_zero = ($signed(rs_value) >= 0);
assign rs_gt_zero = ($signed(rs_value) >  0);
assign rs_le_zero = ($signed(rs_value) <= 0);
assign rs_lt_zero = ($signed(rs_value) <  0);

assign br_taken = (   inst_beq    &&  rs_eq_rt
                   || inst_bne    && !rs_eq_rt
                   || inst_bgez   &&  rs_ge_zero
                   || inst_bgtz   &&  rs_gt_zero
                   || inst_blez   &&  rs_le_zero
                   || inst_bltz   &&  rs_lt_zero
                   || inst_jal
                   || inst_jalr
                   || inst_j
                   || inst_bltzal && rs_lt_zero
                   || inst_bgezal && rs_ge_zero
                   || inst_jr
                   || inst_syscall
                   || inst_break
                   || inst_eret
                  ) && ds_valid;
assign br_target = (inst_beq || inst_bne || inst_bgez || inst_bgtz || inst_blez || inst_bltz || inst_bltzal || inst_bgezal) ? (fs_pc + {{14{imm[15]}}, imm[15:0], 2'b0}) :
                   (inst_jr  || inst_jalr )              ? rs_value :
                   (inst_syscall||inst_break)                        ? 32'hbfc00380:
                   (inst_eret)                           ? cp0_epc:
                   /*inst_jal or inst_j*/               {fs_pc[31:28], jidx[25:0], 2'b0};





always @(posedge clk) begin
  if (reset) begin
    bd_valid<=0;    
  end
  else if (br_taken &&~ inst_syscall&&~ inst_break) begin
    bd_valid<=1;
  end
  else begin
    bd_valid<=0;
  end
end

assign ds_bd = inst_syscall && bd_valid;
endmodule
