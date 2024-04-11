module csr(
    //!需要新增接口: pc, is_exc, is_return?
    // pc:异常发生时，pc写入ERA中
    //is_exc:记录异常是否发生，一旦异常发生，将保存CRMD位域的旧值，调整PLV等级，将IE域置0
    //! 新增接口era, eentry

    //! 新增接口Ecode EsubCode
    input clk,reset,

    input [13:0] raddr,
    input [31:0] rj_value,
    output[31:0] rdata,
    output reg[31:0] ERA,
    output reg[31:0] EENTRY,

    input [1:0]  we,
    input [13:0] waddr,
    input [31:0] wdata,
    input [31:0] pc,
    input is_exc, is_ret,
    input [5:0] Ecode,
    input [8:0] EsubCode
    
);

reg [31:0] CRMD, PRMD, ESTAT, SAVE1, SAVE2, SAVE3, SAVE0;

// 0 和 1
always@(posedge clk) begin
    if(reset)
        CRMD <= 32'h00000008;//初始化要求！
    else if(is_exc) begin
        //PPLV = PLV
        PRMD[1:0] <= CRMD[1:0];
        // PIE = IE
        PRMD[2] <= CRMD[2];
        //PLV 置 0
        CRMD[1:0] <= 2'b0;
        // IE置0
        CRMD[2] <= 1'b0;
    end
    else if(is_ret) begin
        CRMD[1:0] <= PRMD[1:0];
        CRMD[2] <= PRMD[2];
    end
    else if(we[0])begin
        if(waddr == 14'h0)
            CRMD <= wdata;
        else if(waddr == 14'h1)
            PRMD <= wdata;
    end

    else if(we[1])begin
        if(waddr == 14'h0)
            CRMD <= CRMD & ~rj_value | wdata & rj_value;
        else if(waddr == 14'h1)
            PRMD <= PRMD & ~rj_value | wdata & rj_value;  
    end

end
// 5
always@(posedge clk)
    if(reset)
        ESTAT <= 32'h00000000;
    else if(is_exc) begin
        ESTAT[21:16] <= Ecode;
        ESTAT[30:22] <= EsubCode;
    end
    else if(we[0] && waddr == 14'h5)
        ESTAT <= wdata;
    else if(we[1] && waddr == 14'h5)
        ESTAT <= ESTAT & ~rj_value | wdata & rj_value;

// 6
always@(posedge clk)
    if(reset)
        ERA <= 32'h00000000;
    else if(is_exc)
        ERA <= pc;
    else if(we[0] && waddr == 14'h6)
        ERA <= wdata;
    else if(we[1] && waddr == 14'h6)
        ERA <= ERA & ~rj_value | wdata & rj_value;

// c
always@(posedge clk)
    if(reset)
        EENTRY <= 32'h00000000;
    else if(we[0] && waddr == 14'hc)
        EENTRY <= wdata;
    else if(we[1] && waddr == 14'hc)
        EENTRY <= EENTRY & ~rj_value | wdata & rj_value;

// 30 
always@(posedge clk)
    if(reset)
        SAVE0 <= 32'h00000000;
    else if(we[0] && waddr == 14'h30)
        SAVE0 <= wdata;
    else if(we[1] && waddr == 14'h30)
        SAVE0 <= SAVE0 & ~rj_value | wdata & rj_value;
// 31 
always@(posedge clk)
    if(reset)
        SAVE1 <= 32'h00000000;
    else if(we[0] && waddr == 14'h31)
        SAVE1 <= wdata;
    else if(we[1] && waddr == 14'h31)
        SAVE1 <= SAVE1 & ~rj_value | wdata & rj_value;
// 32
always@(posedge clk)
    if(reset)
        SAVE2 <= 32'h00000000;
    else if(we[0] && waddr == 14'h32)
        SAVE2 <= wdata;
    else if(we[1] && waddr == 14'h32)
        SAVE2 <= SAVE2 & ~rj_value | wdata & rj_value;
// 33
always@(posedge clk)
    if(reset)
        SAVE3 <= 32'h00000000;
    else if(we[0] && waddr == 14'h33)
        SAVE3 <= wdata;
    else if(we[1] && waddr == 14'h33)
        SAVE3 <= SAVE3 & ~rj_value | wdata & rj_value;


assign rdata = raddr == 14'h0 ? CRMD :
               raddr == 14'h1 ? PRMD :
               raddr == 14'h5 ? ESTAT :
               raddr == 14'h6 ? ERA :
               raddr == 14'h30 ? SAVE0 :
               raddr == 14'h31 ? SAVE1 :
               raddr == 14'h32 ? SAVE2 :
               raddr == 14'h33 ? SAVE3 : 32'h0;


endmodule