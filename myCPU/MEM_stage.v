module MEM_stage(
    input [31:0] mem_result, alu_result, rkd_value, alu_result_st,
    input rf_or_mem,mem_en, valid, 
    
    output [31:0] rf_wdata, data_sram_addr, data_sram_wdata,
    output [3:0] data_sram_we
);

// assign data_sram_we    = {4{mem_en_EXE && valid}};
// assign data_sram_addr  = alu_result;//这里会取旧值，所以应该前递
// assign data_sram_wdata = rkd_value_EXE;//理由同上
assign data_sram_we    = {4{mem_en && valid}};
assign data_sram_addr  = alu_result;
assign data_sram_wdata = rkd_value;

assign rf_wdata = rf_or_mem ? mem_result : alu_result_st;
endmodule
