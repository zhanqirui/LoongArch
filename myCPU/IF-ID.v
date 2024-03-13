module IF_ID(
    input clk,
    input rst,
    input we,IF_fresh,
    input wire [31:0] PC,
    input wire [31:0] inst,
    
    output reg [31:0] out_pc,
    output reg [31:0] out_inst
);

always @(posedge clk) begin
    if(rst) begin
        out_pc <= 32'b0;
        out_inst <= 32'b0;
    end
    else if(IF_fresh)begin
        out_pc <= PC;
        out_inst <= 32'b0;
    end
    else if(we && PC != 32'h1bfffffc)begin
        out_pc <= PC;
        out_inst <= inst;
    end
end



endmodule