`include "DEFINE.vh"

module chector(
    input [`DS_TO_CHE_WD-1:0] ds_to_che_bus,
    input [`ES_TO_CHE_WD-1:0] es_to_che_bus,
    input [`MS_TO_CHE_WD-1:0] ms_to_che_bus,
    input [`WS_TO_CHE_WD-1:0] ws_to_che_bus,

    output wire is_stall
);
wire [4:0] rd_MEM, rd_EXE, rd_WB, rj, rk;
wire rf_we_EXE, rf_we_MEM, rf_we_WB, is_imm;
wire hazard_exe, hazard_mem, need_stall;

assign {is_imm, rj, rk} = ds_to_che_bus;
assign {rf_we_EXE, rd_EXE} = es_to_che_bus;
assign {rf_we_MEM, rd_MEM} = ms_to_che_bus;
assign {rf_we_WB, rd_WB} = ws_to_che_bus;

assign hazard_exe = rf_we_EXE & (rd_EXE != 0) & ((rd_EXE == rj) | (~is_imm & (rd_EXE == rk)));
assign hazard_mem = rf_we_MEM & (rd_MEM != 0) & ((rd_MEM == rj) | (~is_imm & (rd_MEM == rk)));
assign hazard_wb = rf_we_WB & (rd_WB != 0) & ((rd_WB == rj) | (~is_imm & (rd_WB == rk)));

assign is_stall = hazard_exe | hazard_mem | hazard_wb;

endmodule