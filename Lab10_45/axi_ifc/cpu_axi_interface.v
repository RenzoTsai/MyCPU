`define READ_FREE    3'd0
`define READ_VALID   3'd1
`define READ_READY	 3'd2
`define READ_OK		 3'd3
`define READ_END 	 3'd4
`define WRITE_FREE   3'd0
`define WRITE_VALID  3'd1
`define WRITE_READY	 3'd2
`define WRITE_BREADY 3'd3
`define WRITE_OK 	 3'd4
`define WRITE_END 	 3'd5


module cpu_axi_interface(
    input		clk,
	input		resetn,        

    //inst sram-like 
    input 			inst_req,
    input 			inst_wr,
    input 	[ 1:0]	inst_size,
    input 	[31:0]	inst_addr,
    input 	[31:0]	inst_wdata,
    output	[31:0]	inst_rdata,
    output			inst_addr_ok,
    output			inst_data_ok,
    
    //data sram-like 
    input	 		data_req,
    input 			data_wr,
    input 	[ 1:0]	data_size,
    input 	[31:0]	data_addr,
    input 	[31:0]	data_wdata,
    output 	[31:0]	data_rdata,
    output 			data_addr_ok,
    output 			data_data_ok,

    //axi
    //ar
    output 	[ 3:0]	arid,      
    output 	[31:0]	araddr,    
    output 	[ 7:0]	arlen,   
    output  [ 2:0]	arsize,
    output 	[ 1:0]	arburst,
    output 	[ 1:0]	arlock,
    output 	[ 3:0]	arcache,
    output 	[ 2:0]	arprot,
    output 			arvalid,
    input			arready,
    //r              
    input	[ 3:0]	rid,
    input	[31:0]	rdata,
    input	[ 1:0]	rresp,
    input			rlast,
    input			rvalid,
    output 			rready,
    //aw           
    output 	[ 3:0]	awid,
    output 	[31:0]	awaddr,
    output 	[ 7:0]	awlen,
    output 	[ 2:0]	awsize,
    output 	[ 1:0]	awburst,
    output 	[ 1:0]	awlock,
    output 	[ 3:0]	awcache,
    output 	[ 2:0]	awprot,
    output 			awvalid,
    input			awready,
    //w          
    output 	[ 3:0]	wid,
    output 	[31:0]	wdata,
    output 	reg[ 3:0]	wstrb,
    output 			wlast,
    output 			wvalid,
    input			wready,
    //b              
    input	[ 3:0]	bid,
    input	[ 1:0]	bresp,
    input			bvalid,
    output 			bready
);

reg [31:0] inst_addr_buf;
reg [31:0] inst_wdata_buf;
reg [31:0] data_addr_buf;
reg [31:0] data_wdata_buf;
reg [31:0] inst_rdata_buf;
reg [31:0] data_rdata_buf;
wire [ 1:0] read_size;
wire [ 1:0] write_size;
wire [31:0] read_addr;
wire [31:0] write_addr;
// reg [31:0] read_addr;
// reg [31:0] write_addr;
reg [1:0]inst_ok_flag;
reg [1:0]data_ok_flag;

reg [2:0] read_status;
reg [2:0] write_status;

reg read_req_from;
reg write_req_from;

always @(posedge clk) begin
	if (!resetn) begin
		read_req_from <= 0;
	end
	else if (read_status==`READ_FREE && inst_req && !inst_wr) begin
		read_req_from <= 0;        //read from inst
	end
	else if (read_status==`READ_FREE && data_req && !data_wr) begin
		read_req_from <= 1;		   //read from data
	end
end

always @(posedge clk) begin
	if (!resetn) begin
		write_req_from <= 0;
	end
	else if (write_status==`WRITE_FREE && inst_req && inst_wr) begin
		write_req_from <= 0;	  //write from inst
	end
	else if (write_status==`WRITE_FREE && data_req && data_wr) begin
		write_req_from <= 1;	  //write from data
	end
end


always @(posedge clk) begin
	if (!resetn) begin
		read_status <= `READ_FREE;
	end
	else if (read_status==`READ_FREE && ((inst_req && !inst_wr && write_status==`WRITE_FREE && !write_req_from ) || (data_req && !data_wr && write_status==`WRITE_FREE && write_req_from)) ) begin
		read_status <= `READ_VALID;
	end
	else if (read_status==`READ_VALID && arready) begin
		read_status <= `READ_READY;
	end
	else if (read_status==`READ_READY && rvalid) begin
		read_status <= `READ_OK;
	end
	else if (read_status==`READ_OK && inst_ok_flag!=1 && data_ok_flag!=1) begin
		read_status <= `READ_END;
	end
	else if (read_status==`READ_END) begin
		read_status <= `READ_FREE;
	end
end

always @(posedge clk) begin
	if (!resetn) begin
		write_status <= `WRITE_FREE;
	end
	else if (write_status==`WRITE_FREE && ((inst_req && inst_wr && read_status==`READ_FREE) || (data_req && data_wr && read_status==`READ_FREE))) begin
		write_status <= `WRITE_VALID;
	end
	else if (write_status==`WRITE_VALID && awready  && (inst_addr_ok || data_addr_ok)) begin
		write_status <= `WRITE_READY;

	end
	else if (write_status==`WRITE_READY && wready) begin
		write_status <= `WRITE_BREADY;
	end
	else if (write_status==`WRITE_BREADY && bvalid) begin
		write_status <= `WRITE_OK;
	end
	else if (write_status==`WRITE_OK && inst_ok_flag!=2 && data_ok_flag!=2)begin
		write_status <= `WRITE_END;
	end
	else if (write_status==`WRITE_END) begin
		write_status <= `WRITE_FREE;
	end
end





//ar
assign arid = (inst_req && !inst_wr)? 4'd0:
			  (data_req && !data_wr)? 4'd1:4'd0;



assign araddr = read_addr;



assign	arsize = {1'b0,read_size};


assign arlen   = 8'b0;
assign arburst = 2'b01;
assign arlock  = 2'b0;
assign arcache = 4'b0;
assign arprot  = 3'b0;

assign  arvalid = (read_status==`READ_VALID /**/);

//r
assign  rready = (read_status==`READ_READY) ;


//aw
assign awid    = 4'd1;
assign awlen   = 8'b0 ;
assign awburst = 2'b01;
assign awlock  = 2'b0;
assign awcache = 4'b0;
assign awprot  = 3'b0;
assign awaddr = write_addr;
assign awsize = {1'b0,write_size};
assign awvalid= (write_status==`WRITE_VALID /*&&*/);
		


//w
assign wid     = 4'd1;
assign wlast   = 1'b1;
wire [3:0] wstrb_t;
assign wstrb_t   = (write_size==2'b00 && write_addr[1:0]==2'b00)?4'b0001:
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

always @(posedge clk) begin
	if (!resetn) begin
		wstrb <= 0;
	end
	else if (write_status==`WRITE_VALID) begin
		wstrb <= wstrb_t;
	end
end


assign wvalid = (write_status==`WRITE_READY /*&&*/);
assign wdata = (!write_req_from)?inst_wdata_buf:data_wdata_buf;



//b
assign  bready = (write_status==`WRITE_BREADY);
		
always @(posedge clk) begin
	if (!resetn) begin
		inst_ok_flag <= 2'd0;
	end
	else if ((write_status==`WRITE_VALID && !write_req_from && awready && inst_ok_flag!=2)) begin
		inst_ok_flag <= 2'd1; //write flag
	end
	else if ((read_status==`READ_VALID && !read_req_from && arready && inst_ok_flag!=1)) begin
		inst_ok_flag <= 2'd2; //read flag
	end
	else if (read_status==`READ_OK||(write_status==`WRITE_OK)) begin
		inst_ok_flag <= 2'd0;
	end
end

always @(posedge clk) begin
	if (!resetn) begin
		data_ok_flag <= 2'd0;
	end
	else if ((write_status==`WRITE_VALID && write_req_from && awready&& data_ok_flag!=2)) begin
		data_ok_flag <= 2'd1; //write flag
	end
	else if ((read_status==`READ_VALID && read_req_from && arready && data_ok_flag!=1)) begin
		data_ok_flag <= 2'd2; //read flag
	end
	else if (read_status==`READ_OK||write_status==`WRITE_OK) begin
		data_ok_flag <= 2'd0;
	end
end
//inst sram-like 
assign inst_addr_ok = ((write_status==`WRITE_VALID && !write_req_from && awready) || (read_status==`READ_VALID && !read_req_from && arready)) ;
assign inst_data_ok = ((write_status==`WRITE_END && !write_req_from ) || (read_status==`READ_END && !read_req_from)) ;
assign inst_rdata = inst_rdata_buf;

//inst_wdata_buf
always @(posedge clk) begin
	if (!resetn) begin
		inst_wdata_buf <= 32'd0;
	end
	else if (write_status==`WRITE_VALID && data_addr_ok) begin
		inst_wdata_buf <= inst_wdata;					//Write Ready State
	end
end

//inst_rdata_buf
always @(posedge clk) begin
	if (!resetn) begin
		inst_rdata_buf <= 0;
	end
	else if (read_status==`READ_READY && rvalid && !read_req_from) begin
		inst_rdata_buf <= rdata;
	end
end



//data sram-like 
assign data_addr_ok = ((write_status==`WRITE_VALID && write_req_from && awready) || (read_status==`READ_VALID &&  read_req_from && arready)) ;
assign data_data_ok = ((write_status==`WRITE_END &&  write_req_from ) || (read_status==`READ_END &&  read_req_from)) ;
assign data_rdata = data_rdata_buf;

//data_wdata_buf
always @(posedge clk) begin
	if (!resetn) begin
		data_wdata_buf <= 32'd0;
	end
	else if (write_status==`WRITE_VALID && data_addr_ok) begin
		data_wdata_buf <= data_wdata;					//Write Ready State
	end
end

//data_rdata_buf
always @(posedge clk) begin
	if (!resetn) begin
		data_rdata_buf <= 0;
	end
	else if (read_status==`READ_READY && rvalid && read_req_from) begin
		data_rdata_buf <= rdata;
	end
end


assign write_size = (write_status==`WRITE_VALID && awready && !write_req_from)? inst_size:
				    (write_status==`WRITE_VALID && awready &&  write_req_from)? data_size:0;


assign read_size = (read_status==`READ_VALID && arready && !read_req_from)? inst_size:
				   (read_status==`READ_VALID && arready &&  read_req_from)? data_size:0;



//addr_buf

assign 	write_addr =(write_status==`WRITE_VALID && awready &&!write_req_from )? inst_addr:
 					(write_status==`WRITE_VALID && awready && write_req_from )?	data_addr:0;


assign 	read_addr =(read_status==`READ_VALID && arready &&!read_req_from )? inst_addr:
 				   (read_status==`READ_VALID && arready && read_req_from )?	data_addr:0;

endmodule


