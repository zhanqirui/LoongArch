module chector(
    input [4:0] rd_mem, rd_exe, rj, rk,
    input rf_we_EXE, rf_we_MEM, is_imm,

    output wire [1:0] is_stall
);

wire hazard_exe, hazard_mem, need_stall;

assign hazard_exe = rf_we_EXE & (rd_exe != 0) & ((rd_exe == rj) | (~is_imm & (rd_exe == rk)));
assign hazard_mem = rf_we_MEM & (rd_mem != 0) & ((rd_mem == rj) | (~is_imm & (rd_mem == rk)));

assign is_stall = hazard_exe ? 2'd2 :
                  hazard_mem ? 2'd1 :
                  2'd0;


endmodule