//cp0_regs
wire [31:0] cp0_status;
wire cp0_status_bev;
reg  [7:0] cp0_status_im;
reg cp0_status_exl;
reg cp0_status_ie;

assign cp0_status_bev = 1'b1;
assign cp0_status = {   {9{1'b0}},      //31:23
                        cp0_status_bev, //22    
                        6'd0,           //21:16
                        cp0_status_im,  //15:8
                        6'd0,           //7:2
                        cp0_status_exl, //1
                        cp0_status_ie   //0
                    } ;


wire [31:0] cp0_cause;
reg cp0_cause_bd;
reg cp0_cause_ti;
reg [7:0] cp0_cause_ip;
reg [4:0] cp0_cause_excode;

assign cp0_cause =  {   cp0_cause_bd,     //31
                        cp0_cause_ti,     //30
                        {14{1'b0}},       //29:16
                        cp0_cause_ip,     //15:8
                        1'b0,             //7
                        cp0_cause_excode, //6:2
                        {2{1'b0}}         //1:0  
                    } ;

reg [31:0] cp0_epc;