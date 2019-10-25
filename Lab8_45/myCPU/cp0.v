//CP0_REG
wire [31:0] cp0_wdata;
wire wb_ex;
wire wb_bd;
wire eret_flush;
wire mtc0_we;
wire count_eq_compare;
wire [ 7:0] cp0_addr;
wire [ 4:0] wb_excode;
wire [ 5:0] ext_int_in;

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
    else if (wb_ex) 
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
    else if (wb_ex && !cp0_status_exl) 
    cp0_cause_bd <= wb_bd;
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
    else if (wb_ex)
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
reg [31:0] cp0_epc;

always @(posedge clk) begin
    if (wb_ex && !cp0_status_exl)
        cp0_epc <= wb_bd ? ws_pc – 3'h4 : ws_pc;
    else if (mtc0_we && cp0_addr==`CR_EPC) 
        cp0_epc <= cp0_wdata;
end