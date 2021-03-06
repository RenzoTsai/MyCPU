`ifndef MYCPU_H
    `define MYCPU_H

    `define BR_BUS_WD       33
    `define FS_TO_DS_BUS_WD 64
    `define DS_TO_ES_BUS_WD 167
    `define ES_TO_MS_BUS_WD 122
    `define MS_TO_WS_BUS_WD 84
    `define WS_TO_RF_BUS_WD 73
    `define WS_TO_FS_BUS_WD 33
    `define LW_TYPE         3'b000
    `define LB_TYPE  	    3'b001
    `define LBU_TYPE        3'b010
    `define LH_TYPE         3'b011
    `define LHU_TYPE        3'b100
    `define LWL_TYPE        3'b101
    `define LWR_TYPE        3'b110

    `define SW_TYPE         3'b000
    `define SB_TYPE         3'b001
    `define SH_TYPE         3'b011
    `define SWL_TYPE        3'b101
    `define SWR_TYPE        3'b110

    `define CR_COMPARE      8'b01011000
    `define CR_STATUS       8'b01100000
    `define CR_CAUSE        8'b01101000
    `define CR_EPC          8'b01110000

    `define SYSCALL         3'b001

`endif
