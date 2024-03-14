module mycpu_top(
    input  wire        clk,
    input  wire        resetn,      //low valid
    // inst sram interface
    output wire [3:0]  inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    // data sram interface
    output wire [3:0]  data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata,

    output wire inst_sram_en,
    output wire data_sram_en
);




wire pc_to_next = 1'b1;    //IF stage valid

wire br_taken;                //if there is a pc branch taken place
wire [31:0] br_target;        //branch target addr
wire  [31:0] pc;
wire [31:0] nextpc;
wire IF_fresh;

//RF
wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;
wire        rf_we   ;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;

//ALU
wire [11:0] alu_op; //12 types of operation, one-hot
wire        rf_or_mem;
wire        mem_we;
wire [31:0] rkd_value;

wire [31:0] alu_src1   ;
wire [31:0] alu_src2   ;
wire [31:0] alu_result ;


//ID/EXE寄存器
wire id_to_exe_en = 1'b1;
wire br_taken_EXE, rf_we_EXE, rf_or_mem_EXE, mem_en_EXE;
wire [31:0] br_target_EXE, rkd_value_EXE, alu_src1_EXE, alu_src2_EXE, PC_EXE;
wire [4:0] rf_waddr_EXE;
wire [11:0] alu_op_EXE;
wire [3:0] data_sram_we_EXE;

//EXE_MEM寄存器
wire exe_mem_en, rf_we_MEM, br_taken_MEM, rf_or_mem_MEM, mem_en_MEM;
wire [3:0] data_sram_we_MEM;
wire [31:0] rkd_value_MEM, alu_result_MEM, br_target_MEM, PC_MEM;
wire [4:0] rf_waddr_MEM;
assign exe_mem_en = 1'b1;

//MEM/WB寄存器
wire rf_we_WB, mem_wb_en;
wire [4:0] rf_waddr_WB;
wire [31:0] rf_wdata_WB, PC_WB;


//reset和valid信号生成
reg         reset;
always @(posedge clk) 
    reset <= ~resetn;

reg         valid;
always @(posedge clk) begin
    if (reset) begin
        valid <= 1'b0;
    end
    else begin
        valid <= 1'b1;
    end
end
//reset和valid信号生成pc


wire [31:0] inst;

IF_stage U_IF_stage(
    .clk(clk),
    .reset(reset),
    .br_taken(br_taken),
    .br_target(br_target),
    .inst_sram_rdata(inst_sram_rdata),

    .inst_sram_en(inst_sram_en),
    .inst_sram_we(inst_sram_we),
    .pc(pc),
    .inst_sram_addr(inst_sram_addr),
    .inst_sram_wdata(inst_sram_wdata),
    .inst(inst)
);
                                                   

//pc
wire ID_en;
assign ID_en = 1'b1;
wire [31:0] PC_ID;
wire [31:0] inst_ID;
IF_ID U_IF_ID(
    .clk(clk),
    .rst(reset),
    .IF_fresh(IF_fresh),
    .we(ID_en),
    .PC(pc),
    .inst(inst),

    .out_pc(PC_ID),
    .out_inst(inst_ID)
);

ID_stage u_ID_stage(
    .clk(clk),
    .valid(valid),
    .rf_we_WB(rf_we_WB),
    .pc(PC_ID),
    .inst(inst_ID),
    .rf_waddr_WB(rf_waddr_WB),
    .rf_wdata_WB(rf_wdata_WB),

    .br_taken(br_taken),
    .rf_or_mem(rf_or_mem),
    .mem_we(mem_we),
    .rf_we(rf_we),
    .IF_fresh(IF_fresh),
    .rkd_value(rkd_value),
    .br_target(br_target),
    .alu_src1(alu_src1),
    .alu_src2(alu_src2),
    .dest(rf_waddr),
    .alu_op(alu_op)
);

//ID/EXE寄存器

ID_EXE U_ID_EXE(
    .clk(clk),
    .rst(reset),
    .id_to_exe_en(id_to_exe_en),
    .br_taken_in(br_taken),
    .br_target_in(br_target),
    .PC_in(PC_ID),

    .data_sram_we_in(data_sram_we),
    .rkd_value_in(rkd_value),
    .mem_en_in(mem_we),

    .alu_op_in(alu_op),
    .alu_src1_in(alu_src1),
    .alu_src2_in(alu_src2),

    .rf_we_in(rf_we),
    .rf_waddr_in(rf_waddr),
    .rf_or_mem_in(rf_or_mem),

    .br_taken(br_taken_EXE),
    .br_target(br_target_EXE),
    .PC(PC_EXE),
    .data_sram_we(data_sram_we_EXE),
    .rkd_value(rkd_value_EXE),
    .mem_en(mem_en_EXE),
    .alu_op(alu_op_EXE),
    .alu_src1(alu_src1_EXE),
    .alu_src2(alu_src2_EXE),
    .rf_we(rf_we_EXE),
    .rf_waddr(rf_waddr_EXE),
    .rf_or_mem(rf_or_mem_EXE)
);

//EXE
alu u_alu(
    .alu_op     (alu_op_EXE    ),
    .alu_src1   (alu_src1_EXE  ),
    .alu_src2   (alu_src2_EXE  ),
    .alu_result (alu_result)
    );

//EXE_MEM寄存器

EXE_MEM U_EXE_MEM(
    .clk(clk),
    .rst(reset),
    .exe_mem_en(exe_mem_en),
    .data_sram_we_in(data_sram_we_EXE),
    .rkd_value_in(rkd_value_EXE),
    .mem_en_in(mem_en_EXE),
    .alu_result_in(alu_result),
    .rf_we_in(rf_we_EXE),
    .rf_waddr_in(rf_waddr_EXE),
    .rf_or_mem_in(rf_or_mem_EXE),
    .br_taken_in(br_taken_EXE),
    .br_target_in(br_target_EXE),
    .PC_in(PC_EXE),

    .data_sram_we(data_sram_we_MEM),
    .rkd_value(rkd_value_MEM),
    .mem_en(mem_en_MEM),
    .alu_result(alu_result_MEM),
    .rf_we(rf_we_MEM),
    .rf_waddr(rf_waddr_MEM),
    .rf_or_mem(rf_or_mem_MEM),
    .br_taken(br_taken_MEM),
    .br_target(br_target_MEM),
    .PC(PC_MEM)
);


// assign data_sram_we    = {4{mem_en_EXE && valid}};
// assign data_sram_addr  = alu_result;//这里会取旧值，所以应该前递
// assign data_sram_wdata = rkd_value_EXE;//理由同上

MEM_stage U_MEM_stage(
    .mem_result(data_sram_rdata),
    .alu_result(alu_result),
    .alu_result_st(alu_result_MEM),
    .rkd_value(rkd_value_EXE),
    .rf_or_mem(rf_or_mem_MEM),
    .mem_en(mem_en_EXE),
    .valid(valid),

    .rf_wdata(rf_wdata),
    .data_sram_addr(data_sram_addr),
    .data_sram_wdata(data_sram_wdata),
    .data_sram_we(data_sram_we)
);

//MEM/WB寄存器

assign mem_wb_en = 1'b1;
MEM_WB U_MEM_WB(
    .clk(clk),
    .rst(reset),
    .mem_wb_en(mem_wb_en),
    .rf_we_in(rf_we_MEM),
    .rf_waddr_in(rf_waddr_MEM),
    .rf_wdata_in(rf_wdata),
    .PC_in(PC_MEM),

    .rf_we(rf_we_WB),
    .rf_waddr(rf_waddr_WB),
    .rf_wdata(rf_wdata_WB),
    .PC(PC_WB)
);



// debug info generate
assign debug_wb_pc       = PC_WB;
assign debug_wb_rf_we    = {4{rf_we_WB}};
assign debug_wb_rf_wnum  = rf_waddr_WB;
assign debug_wb_rf_wdata = rf_wdata_WB;
// debug info generate

assign inst_sram_en = 1'b1;
assign data_sram_en = 1'b1;

endmodule
