`define WRITE_FREE 2'b00
`define WRITE_AW   2'b01
`define WRITE_W    2'b10
`define WRITE_B    2'b11

`define AR_FREE    1'b0
`define AR_READY   1'b1
`define R_FREE     1'b0
`define R_READY    1'b1

`define WAITING 2'b00
`define READING 2'b01
`define WRITING 2'b10
 
module cpu_axi_interface(
    input       clk,
    input       resetn,        

    //inst sram-like 
    input           inst_req,
    input           inst_wr,
    input   [ 1:0]  inst_size,
    input   [31:0]  inst_addr,
    input   [31:0]  inst_wdata,
    output  [31:0]  inst_rdata,
    output          inst_addr_ok,
    output          inst_data_ok,
    
    //data sram-like 
    input           data_req,
    input           data_wr,
    input   [ 1:0]  data_size,
    input   [31:0]  data_addr,
    input   [31:0]  data_wdata,
    output  [31:0]  data_rdata,
    output          data_addr_ok,
    output          data_data_ok,

    //axi
    //ar
    output  [ 3:0]  arid,      
    output  [31:0]  araddr,    
    output  [ 7:0]  arlen,   
    output  [ 2:0]  arsize,
    output  [ 1:0]  arburst,
    output  [ 1:0]  arlock,
    output  [ 3:0]  arcache,
    output  [ 2:0]  arprot,
    output          arvalid,
    input           arready,
    //r              
    input   [ 3:0]  rid,
    input   [31:0]  rdata,
    input   [ 1:0]  rresp,
    input           rlast,
    input           rvalid,
    output          rready,
    //aw           
    output  [ 3:0]  awid,
    output  [31:0]  awaddr,
    output  [ 7:0]  awlen,
    output  [ 2:0]  awsize,
    output  [ 1:0]  awburst,
    output  [ 1:0]  awlock,
    output  [ 3:0]  awcache,
    output  [ 2:0]  awprot,
    output          awvalid,
    input           awready,
    //w          
    output  [ 3:0]  wid,
    output  [31:0]  wdata,
    output  [ 3:0]  wstrb,
    output          wlast,
    output          wvalid,
    input           wready,
    //b              
    input   [ 3:0]  bid,
    input   [ 1:0]  bresp,
    input           bvalid,
    output          bready
);
    
    reg [1:0] inst_status_r;  
    reg [1:0] data_status_r;

    reg write_allowin_r;    
    reg ar_allowin_r;        

    //inst sram-like
    reg inst_addr_ok_r;
    reg inst_data_ok_r;

    //data sram-like
    reg data_addr_ok_r;
    reg data_data_ok_r;

    //ar
    wire [3:0] arid_choice;
    reg arid_r;
    always @(posedge clk) begin
        if (!resetn)
            arid_r <= 4'b0;
        else if (read_req && ar_status==`AR_FREE)
            arid_r <= arid_choice;
    end

    assign arid_choice    = (data_req && !data_wr && data_addr_ok)? 4'd1 : 4'd0;
    assign arid = arid_r;



    reg [31: 0]   araddr_r;
    reg [ 2: 0]   arsize_r;
    reg           arvalid_r;
    
    //r
    reg           rready_r;
    reg [31: 0]   rdata_r;

    //aw


    reg [31: 0]   awaddr_r;
    reg [ 2: 0]   awsize_r;
    reg           awvalid_r;

    //w

    reg [31: 0]   wdata_r;
    reg [ 3: 0]   wstrb_r;
    reg           wvalid_r;

    //b
    reg           bready_r;


    //aw and w
    wire write_req;
    reg [ 1: 0]   write_status;
    always @(posedge clk) begin
        if (!resetn) 
            write_status <= `WRITE_FREE;
        else if (write_req && write_status==`WRITE_FREE)
            write_status <= `WRITE_AW;
        else if (awready && awvalid && write_status==`WRITE_AW) 
            write_status <= `WRITE_W;
        else if (wready && wvalid && write_status==`WRITE_W)
            write_status <= `WRITE_FREE;
    end

    always @(posedge clk) begin
        if (!resetn)
            write_allowin_r <= 1'b1;
        else if (write_req && write_status==`WRITE_FREE)
            write_allowin_r <= 1'b0;
        else if (wready && wvalid && wlast && (write_status==`WRITE_W))
            write_allowin_r <= 1'b1;
    end

    // aw
    always @(posedge clk) begin
        if (!resetn) 
            awaddr_r <= 32'b0;
        else if (write_req && write_status==`WRITE_FREE)
            awaddr_r <= write_addr;
    end

    always @(posedge clk) begin
        if (!resetn)
            awsize_r <= 3'b0;
        else if (write_req && write_status==`WRITE_FREE)
            awsize_r <= {1'b0,write_size};
    end

    always @(posedge clk) begin
        if (!resetn)
            awvalid_r <= 1'b0;
        else if (write_req && write_status==`WRITE_FREE)
            awvalid_r <= 1'b1;
        else if (awready && awvalid && write_status==`WRITE_AW)
            awvalid_r <= 1'b0;
    end

    always @(posedge clk) begin
        if (!resetn)
            wdata_r <= 32'b0;
        else if (write_req && write_status==`WRITE_FREE)
            wdata_r <=write_data;
    end

    
    always @(posedge clk) begin
        if (!resetn)
            wstrb_r <= 4'b0;
        else if (write_req && write_status==`WRITE_FREE)
            wstrb_r <= wstrb_t;
    end
    wire [1:0] write_size;
    wire [31:0]write_addr;
    wire [31:0]write_data;
    wire [3:0] wstrb_t;
    assign write_addr     = data_addr;
    assign write_size     = data_size;
    assign write_data     = data_wdata;    
    assign wstrb_t = (write_size==2'b00 && write_addr[1:0]==2'b00)?4'b0001:
                     (write_size==2'b00 && write_addr[1:0]==2'b01)?4'b0010:
                     (write_size==2'b00 && write_addr[1:0]==2'b10)?4'b0100:
                     (write_size==2'b00 && write_addr[1:0]==2'b11)?4'b1000:
                     (write_size==2'b01 && write_addr[1:0]==2'b00)?4'b0011:
                     (write_size==2'b01 && write_addr[1:0]==2'b10)?4'b1100:
                     (write_size==2'b10 && write_addr[1:0]==2'b00)?4'b1111:
                     (write_size==2'b00 && write_addr[1:0]==2'b00)?4'b0001:
                     (write_size==2'b01 && write_addr[1:0]==2'b01)?4'b0011:
                     (write_size==2'b10 && write_addr[1:0]==2'b10)?4'b0111:
                     (write_size==2'b10 && write_addr[1:0]==2'b11)?4'b1111:
                     (write_size==2'b10 && write_addr[1:0]==2'b00)?4'b1111:
                     (write_size==2'b10 && write_addr[1:0]==2'b01)?4'b1110:
                     (write_size==2'b01 && write_addr[1:0]==2'b10)?4'b1100:
                     (write_size==2'b00 && write_addr[1:0]==2'b11)?4'b1000:
                     4'b1111; 
// assign wstrb_t  = (write_size==2'd0) ? 4'b0001<<write_addr[1:0] :
//                 (write_size==2'd1) ? 4'b0011<<write_addr[1:0] :
//                  4'b1111;
    // aw
    always @(posedge clk) begin
        if (!resetn)
            wvalid_r <= 1'b0;
        else if (awready && awvalid && write_status==`WRITE_AW)
            wvalid_r <= 1'b1;
        else if (wready && wvalid && write_status==`WRITE_W)
            wvalid_r <= 1'b0;
    end
    
    always @(posedge clk) begin
        if (!resetn)
            bready_r <= 1'b1;
    end
      
    //ar
    wire read_req;
    reg  ar_status;
    always @(posedge clk) begin
        if (!resetn)
            ar_status <= `AR_FREE;
        else if (read_req && ar_status==`AR_FREE)
            ar_status <= `AR_READY;
        else if (arvalid && arready && ar_status==`AR_READY)
            ar_status <= `AR_FREE;
    end

    always @(posedge clk) begin
        if (!resetn)
            ar_allowin_r <= 1'b1;
        else if (read_req && ar_status==`AR_FREE)
            ar_allowin_r <= 1'b0;
        else if (arvalid && arready && ar_status==`AR_READY)
            ar_allowin_r <= 1'b1;
    end

    wire [31:0] read_addr;
    always @(posedge clk) begin
        if (!resetn)
            araddr_r <= 32'b0;
        else if (read_req && ar_status==`AR_FREE)
            araddr_r <= read_addr;
    end

    wire [2:0] read_size;
    always @(posedge clk) begin
        if (!resetn)
            arsize_r <= 3'b0;
        else if (read_req && ar_status==`AR_FREE)
            arsize_r <= read_size;
    end

    always @(posedge clk) begin
        if (!resetn)
            arvalid_r <= 1'b0;
        else if (read_req && ar_status==`AR_FREE)
            arvalid_r <= 1'b1;
        else if (arvalid && arready && ar_status==`AR_READY)
            arvalid_r <= 1'b0;
    end


    always @(posedge clk) begin
        if (!resetn)
            rdata_r <= 32'b0;
        else if (rvalid && rready)
            rdata_r <= rdata;
    end

    assign read_addr     = (data_req & !data_wr & data_addr_ok)? data_addr : inst_addr;
    assign read_size     = (data_req & !data_wr & data_addr_ok)? data_size : inst_size;

    reg is_writing_r; 
    always @(posedge clk) begin
        if (!resetn)
            is_writing_r <= 1'b0;
        else if (bready&&bvalid)
            is_writing_r <= 1'b0;
        else if (write_req && write_status==`WRITE_FREE)
            is_writing_r <= 1'b1;
    end
    reg is_reading_r;
    always @(posedge clk) begin
        if (!resetn) 
            is_reading_r <= 1'b0;
        else if (rready&&rvalid) 
            is_reading_r <= 1'b0;
        else if (read_req && ar_status==`AR_FREE)
            is_reading_r <= 1'b1;
    end

    always @(posedge clk) begin
        if (!resetn)
            inst_status_r <= `WAITING;
        else if (inst_req && !inst_wr && inst_addr_ok && ar_status==`AR_FREE && inst_status_r==`WAITING)
            inst_status_r <= `READING;
        else if (rready && rvalid && inst_status_r==`READING && rid==4'd0)
            inst_status_r <= `WAITING;
        else if (inst_req &&  inst_wr && inst_addr_ok && write_status==`WRITE_FREE && inst_status_r==`WAITING)
            inst_status_r <= `WRITING;
        else if (bready && bvalid && inst_status_r==`WRITING)
            inst_status_r <= `WAITING;
    end

    always @(posedge clk) begin
        if (!resetn)
            data_status_r <= `WAITING;
        else if (data_req && !data_wr && data_addr_ok && ar_status==`AR_FREE && data_status_r==`WAITING)
            data_status_r <= `READING;
        else if (rready && rvalid && data_status_r==`READING && rid==4'd1)
            data_status_r <= `WAITING;
        else if (data_req &&  data_wr && data_addr_ok && write_status==`WRITE_FREE && data_status_r==`WAITING)
            data_status_r <= `WRITING;
        else if (bready && bvalid && data_status_r==`WRITING)
            data_status_r <= `WAITING;
    end


    assign write_req = (data_req &&  data_wr && data_addr_ok); 
    assign read_req  = (inst_req && !inst_wr && inst_addr_ok) || (data_req && !data_wr && data_addr_ok);

    
    wire r_hazard;
    assign r_hazard = araddr_r[31:2]==awaddr_r[31:2] && is_writing_r && ar_status==`AR_READY;
    wire w_hazard;
    assign w_hazard = araddr_r[31:2]==awaddr_r[31:2] && is_reading_r && write_status==`WRITE_W;
    //ar
    assign araddr  = araddr_r;
    assign arsize  = arsize_r;
    assign arvalid = arvalid_r && !r_hazard;
 
    //aw
    assign awaddr  = awaddr_r;
    assign awsize  = awsize_r;
    assign awvalid = awvalid_r && !w_hazard;
    //w
    assign wdata   = wdata_r;
    assign wstrb   = wstrb_r;
    assign wvalid  = wvalid_r;
    //b
    assign bready  = bready_r; 

    always @(posedge clk) begin
        if (!resetn)
            inst_data_ok_r <= 1'b0;
        else if (rready && rvalid && (rid==4'd0))
            inst_data_ok_r <= 1'b1;
        else
            inst_data_ok_r <= 1'b0;
    end
    
    always @(posedge clk) begin
        if (!resetn)
            data_data_ok_r <= 1'b0;
        else if (rready && rvalid && (rid==4'd1))
            data_data_ok_r <= 1'b1;
        else if(bready && bvalid)
            data_data_ok_r <= 1'b1;
        else
            data_data_ok_r <= 1'b0;
    end

    assign inst_addr_ok = (inst_req && !inst_wr && ar_allowin_r   && inst_status_r==`WAITING) &&  
                         !(data_req && !data_wr && ar_allowin_r   && data_status_r==`WAITING) ;  
    assign inst_data_ok = inst_data_ok_r;  
    assign data_addr_ok = (data_req && data_wr  && write_allowin_r && data_status_r==`WAITING) ||  
                          (data_req && !data_wr && ar_allowin_r    && data_status_r==`WAITING) ; 
    assign data_data_ok = data_data_ok_r;

    assign inst_rdata   = rdata_r;
    assign data_rdata   = rdata_r;

    assign rready  = 1'b1;
    assign arlen   = 8'b0;
    assign arburst = 2'b01;
    assign arlock  = 2'b0;
    assign arcache = 4'b0;
    assign arprot  = 3'b0;
    assign awid    = 4'd1;
    assign awlen   = 8'b0;
    assign awburst = 2'b01;
    assign awlock  = 2'b0;
    assign awcache = 4'b0;
    assign awprot  = 3'b0;
    assign wid   = 4'd1;
    assign wlast = 1'b1;

endmodule


