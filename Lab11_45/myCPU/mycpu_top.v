module mycpu_top(
    input  [5 :0] int,
    input         aclk,
    input         aresetn,
//axi
//ar
    output [3 :0] arid   ,
    output [31:0] araddr ,
    output [7 :0] arlen  ,
    output [2 :0] arsize ,
    output [1 :0] arburst,
    output [1 :0] arlock ,
    output [3 :0] arcache,
    output [2 :0] arprot ,
    output        arvalid,
    input         arready,
//r
    input  [3 :0] rid    ,
    input  [31:0] rdata  ,
    input  [1 :0] rresp  ,
    input         rlast  ,
    input         rvalid ,
    output        rready ,
//aw
    output [3 :0] awid   ,
    output [31:0] awaddr ,
    output [7 :0] awlen  ,
    output [2 :0] awsize ,
    output [1 :0] awburst,
    output [1 :0] awlock ,
    output [3 :0] awcache,
    output [2 :0] awprot ,
    output        awvalid,
    input         awready,
//w
    output [3 :0] wid    ,
    output [31:0] wdata  ,
    output [3 :0] wstrb  ,
    output        wlast  ,
    output        wvalid ,
    input         wready ,
//b
    input  [3 :0] bid    ,
    input  [1 :0] bresp  ,
    input         bvalid ,
    output        bready ,
    // trace debug interface
    output [31:0] debug_wb_pc,
    output [ 3:0] debug_wb_rf_wen,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);
reg         reset;
always @(posedge aclk) reset <= ~aresetn;
    // inst sram interface
wire        inst_sram_en;
wire        inst_sram_wen;
wire [ 1:0] inst_sram_size;
wire [31:0] inst_sram_addr;
wire [31:0] inst_sram_wdata;
wire [31:0] inst_sram_rdata;
wire        inst_addr_ok;
wire        inst_data_ok;
    // data sram interface
wire        data_sram_en;
wire        data_sram_wen;
wire [ 1:0] data_sram_size;
wire [31:0] data_sram_addr;
wire [31:0] data_sram_wdata;
wire [31:0] data_sram_rdata;
wire        data_addr_ok;
wire        data_data_ok;

wire         ds_allowin;
wire         es_allowin;
wire         ms_allowin;
wire         ws_allowin;
wire         fs_to_ds_valid;
wire         ds_to_es_valid;
wire         es_to_ms_valid;
wire         ms_to_ws_valid;
wire         out_es_valid;
wire         out_ms_valid;
wire         ws_ex;
wire [ 3:0]  ms_exc_type;
wire [ 3:0]  ws_exc_type;
wire         ms_eret;
wire         eret_flush;

wire [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus;
wire [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus;
wire [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus;
wire [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus;
wire [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus;
wire [`BR_BUS_WD       -1:0] br_bus;
wire [`WS_TO_FS_BUS_WD -1:0] ws_to_fs_bus;


// IF stage
if_stage if_stage(
    .clk            (aclk            ),
    .reset          (reset          ),
    //allowin
    .ds_allowin     (ds_allowin     ),
    //brbus
    .br_bus         (br_bus         ),
    .es_allowin     (es_allowin     ),
    //outputs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    .ws_to_fs_bus   (ws_to_fs_bus   ),
    // inst sram interface
    .inst_sram_en   (inst_sram_en   ),
    .inst_sram_wen  (inst_sram_wen  ),
    .inst_sram_size (inst_sram_size ),
    .inst_sram_addr (inst_sram_addr ),
    .inst_sram_wdata(inst_sram_wdata),
    .inst_sram_rdata(inst_sram_rdata),
    .inst_addr_ok   (inst_addr_ok   ),
    .inst_data_ok   (inst_data_ok   )

);
// ID stage
id_stage id_stage(
    .clk            (aclk            ),
    .reset          (reset          ),
    //allowin
    .es_allowin     (es_allowin     ),
    .ds_allowin     (ds_allowin     ),
    //from fs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    //to es
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //to fs
    .br_bus         (br_bus         ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),

    .es_to_ms_bus   (es_to_ms_bus   ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    .es_to_ms_valid (es_to_ms_valid ),
    .ms_to_ws_valid (ms_to_ws_valid ),
    .out_es_valid   (out_es_valid),
    .out_ms_valid   (out_ms_valid)
);
// EXE stage
exe_stage exe_stage(
    .clk            (aclk            ),
    .reset          (reset          ),
    //allowin
    .ms_allowin     (ms_allowin     ),
    .es_allowin     (es_allowin     ),
    //from ds
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //to ms
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    // data sram interface
    .data_sram_en   (data_sram_en   ),
    .data_sram_wen  (data_sram_wen  ),
    .data_sram_size (data_sram_size ),
    .data_sram_addr (data_sram_addr ),
    .data_sram_wdata(data_sram_wdata),
    .out_es_valid   (out_es_valid   ),
    .data_addr_ok   (data_addr_ok   ),
    .data_data_ok   (data_data_ok   ),
    .ws_ex          (ws_ex          ),
    .ms_exc_type    (ms_exc_type    ),
    .ws_exc_type    (ws_exc_type    ),
    .ms_eret        (ms_eret        ),
    .eret_flush     (eret_flush     )
);
// MEM stage
mem_stage mem_stage(
    .clk            (aclk            ),
    .reset          (reset          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    .ms_allowin     (ms_allowin     ),
    //from es
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    //to ws
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    //from data-sram
    .data_sram_rdata(data_sram_rdata),
    .data_data_ok   (data_data_ok   ),
    .out_ms_valid   (out_ms_valid   ),
    .ws_ex          (ws_ex          ),
    .ms_exc_type    (ms_exc_type    ),
    .ms_eret        (ms_eret        ),
    .eret_flush     (eret_flush     )
);
// WB stage
wb_stage wb_stage(
    .ext_int_in     (int            ),
    .clk            (aclk            ),
    .reset          (reset          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    //from ms
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    .ws_to_fs_bus   (ws_to_fs_bus   ),
    //trace debug interface
    .debug_wb_pc      (debug_wb_pc      ),
    .debug_wb_rf_wen  (debug_wb_rf_wen  ),
    .debug_wb_rf_wnum (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata(debug_wb_rf_wdata),
    .ws_ex          (ws_ex          ),
    .ws_exc_type    (ws_exc_type    ),
    .eret_flush     (eret_flush     )

);



cpu_axi_interface u_axi_ifc(
    .clk           ( aclk          ),
    .resetn        ( aresetn       ),

    //inst sram-like 
    .inst_req      ( inst_sram_en     ),
    .inst_wr       ( inst_sram_wen    ),
    .inst_size     ( inst_sram_size   ),
    .inst_addr     ( inst_sram_addr   ),
    .inst_wdata    ( inst_sram_wdata  ),
    .inst_rdata    ( inst_sram_rdata  ),
    .inst_addr_ok  ( inst_addr_ok     ),
    .inst_data_ok  ( inst_data_ok     ),
    
    //data sram-like 
    .data_req      ( data_sram_en     ),
    .data_wr       ( data_sram_wen    ),
    .data_size     ( data_sram_size   ),
    .data_addr     ( data_sram_addr   ),
    .data_wdata    ( data_sram_wdata  ),
    .data_rdata    ( data_sram_rdata  ),
    .data_addr_ok  ( data_addr_ok     ),
    .data_data_ok  ( data_data_ok     ),

    //axi
    //ar
    .arid      ( arid         ),
    .araddr    ( araddr       ),
    .arlen     ( arlen        ),
    .arsize    ( arsize       ),
    .arburst   ( arburst      ),
    .arlock    ( arlock       ),
    .arcache   ( arcache      ),
    .arprot    ( arprot       ),
    .arvalid   ( arvalid      ),
    .arready   ( arready      ),
    //r              
    .rid       ( rid          ),
    .rdata     ( rdata        ),
    .rresp     ( rresp        ),
    .rlast     ( rlast        ),
    .rvalid    ( rvalid       ),
    .rready    ( rready       ),
    //aw           
    .awid      ( awid         ),
    .awaddr    ( awaddr       ),
    .awlen     ( awlen        ),
    .awsize    ( awsize       ),
    .awburst   ( awburst      ),
    .awlock    ( awlock       ),
    .awcache   ( awcache      ),
    .awprot    ( awprot       ),
    .awvalid   ( awvalid      ),
    .awready   ( awready      ),
    //w          
    .wid       ( wid          ),
    .wdata     ( wdata        ),
    .wstrb     ( wstrb        ),
    .wlast     ( wlast        ),
    .wvalid    ( wvalid       ),
    .wready    ( wready       ),
    //b              
    .bid       ( bid          ),
    .bresp     ( bresp        ),
    .bvalid    ( bvalid       ),
    .bready    ( bready       )
);

endmodule
