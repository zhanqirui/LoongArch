module Scnt(
    input clk,
    input reset,
    output [31:0] cnt_value_l,
    output [31:0] cnt_value_h
);

reg [63:0] cnt;

always@(posedge clk)
    if(reset)
        cnt = 64'h0;
    else 
        cnt = cnt + 1;

assign cnt_value_l = cnt[31:0];
assign cnt_value_h = cnt[63:32];

endmodule