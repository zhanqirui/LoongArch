module nPC(
    input wire [31:0] currentPC,
    input wire br_taken,                //if there is a pc branch taken place
    input wire [31:0] br_target,        //branch target addr
    output wire [31:0] nextpc
);

wire [31:0] seq_pc;

assign seq_pc       = currentPC + 32'h4;
assign nextpc       = br_taken ? br_target : seq_pc;

endmodule