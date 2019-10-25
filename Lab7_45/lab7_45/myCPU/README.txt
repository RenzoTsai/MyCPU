本RTL代码包括8个模块的代码、一个顶层mycpu_top以及一个头文件mycpu.h构成

IF_stage.v:
  CPU取指模块代码

ID_stage.v:
  CPU译码模块代码，采取前递的方式。接入了es_to_ms_bus, es_to_ms_valid, ms_to_ws_bus 和 ms_to_ws_valid，以及来自EXE模块的out_es_valid和来自MEM模块的out_ms_valid。ds_to_es_bus的位宽扩充至153位

EXE_stage.v:
  CPU执行模块代码，输出out_es_valid给ID模块，es_to_ms_bus位宽扩展至108位

MEM_stage.v:
  CPU访存模块代码，输出out_es_valid给ID模块。

WB_stage.v:
  CPU写回模块代码，增加了一位ws_to_rf_bus的位宽，用来传递ws_valid给CPU译码模块

tools.v:
  ID译码模块调用的译码器代码

alu.v:
  EXE模块调用的算术逻辑运算器代码

regfile.v:
  寄存器堆代码，进行数据交互，lab6的reg_file文件包括两个模块：通用寄存器模块和cp0寄存器模块

mycpu_top.v:
  CPU顶层文件，对各模块进行调用，本次试验修改了对应模块的接口

mycpu.h:
  CPU头文件，包括各类位宽的宏定义。