module IF_stage(
    input clk, reset, br_taken,
    input [31:0] br_target, inst_sram_rdata,

    output  inst_sram_en, inst_sram_we,
    output reg [31:0] pc,
    output [31:0] nextpc, inst_sram_addr, inst_sram_wdata, inst
);

wire pc_to_next = 1'b1;
wire [31:0] seq_pc;

always @(posedge clk) begin
    if (reset) begin
        pc <= 32'h1bfffffc;     //trick: to make nextpc be 0x1c000000 during reset 
    end
    else
        if(pc_to_next)  pc <= nextpc;
end

assign seq_pc       = pc + 32'h4;
assign nextpc       = br_taken ? br_target : seq_pc;

assign inst_sram_we    = 4'b0;
assign inst_sram_addr  = nextpc;
assign inst_sram_wdata = 32'b0;

assign inst_sram_en = 1'b1;
assign inst = inst_sram_rdata;


endmodule