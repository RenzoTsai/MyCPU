`ifndef MYCPU_H
    `define MYCPU_H

    `define BR_BUS_WD       33
    `define FS_TO_DS_BUS_WD 68
    `define DS_TO_ES_BUS_WD 168
    `define ES_TO_MS_BUS_WD 154
    `define MS_TO_WS_BUS_WD 118
    `define WS_TO_RF_BUS_WD 43
    `define WS_TO_FS_BUS_WD 34

    `define LW_TYPE         3'b111
    `define LB_TYPE  	    3'b001
    `define LBU_TYPE        3'b010
    `define LH_TYPE         3'b011
    `define LHU_TYPE        3'b100
    `define LWL_TYPE        3'b101
    `define LWR_TYPE        3'b110

    `define SW_TYPE         3'b111
    `define SB_TYPE         3'b001
    `define SH_TYPE         3'b011
    `define SWL_TYPE        3'b101
    `define SWR_TYPE        3'b110

    `define CR_BADVADDR     8'b01000000
    `define CR_COUNT        8'b01001000
    `define CR_COMPARE      8'b01011000
    `define CR_STATUS       8'b01100000
    `define CR_CAUSE        8'b01101000
    `define CR_EPC          8'b01110000

    `define ITR             4'b0001
    `define ADEL_IF         4'b0010
    `define RI              4'b0011
    `define OV              4'b0100
    `define SYSCALL         4'b0101
    `define BREAK           4'b0110
    `define ADES            4'b0111
    `define ADEL_MEM        4'b1000


`endif
