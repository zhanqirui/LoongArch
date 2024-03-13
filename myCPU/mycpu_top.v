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

//ID
wire        inst_add_w;
wire        inst_sub_w;
wire        inst_slt;
wire        inst_sltu;
wire        inst_nor;
wire        inst_and;
wire        inst_or;
wire        inst_xor;
wire        inst_slli_w;
wire        inst_srli_w;
wire        inst_srai_w;
wire        inst_addi_w;
wire        inst_ld_w;
wire        inst_st_w;
wire        inst_jirl;
wire        inst_b;
wire        inst_bl;
wire        inst_beq;
wire        inst_bne;
wire        inst_lu12i_w;

wire        need_ui5;
wire        need_si12;
wire        need_si16;
wire        need_si20;
wire        need_si26;
wire        src2_is_4;

wire [ 4:0] rd;
wire [ 4:0] rj;
wire [ 4:0] rk;
wire [11:0] i12;
wire [19:0] i20;
wire [15:0] i16;
wire [25:0] i26;

//PC
wire pc_to_next = 1'b1;    //IF stage valid

wire br_taken;                //if there is a pc branch taken place
wire [31:0] br_target;        //branch target addr
reg  [31:0] pc;
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
wire        src1_is_pc;
wire        src2_is_imm;
wire        rf_or_mem;
wire        dst_is_r1;
wire        gr_we;
wire        mem_we;
wire        src_reg_is_rd;
wire [4: 0] dest;
wire [31:0] rj_value;
wire [31:0] rkd_value;
wire [31:0] imm;
wire [31:0] br_offs;
wire [31:0] jirl_offs;


wire [31:0] alu_src1   ;
wire [31:0] alu_src2   ;
wire [31:0] alu_result ;

wire [31:0] mem_result;
wire [31:0] final_result;




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

//state transfer
wire ID_en;// not used
wire write_back_en;

assign write_back_en = ~(inst_b | inst_bne | inst_beq | inst_st_w);
assign ID_en = 1'b1;

//inst_sram
wire [31:0] inst;

assign inst_sram_we    = 4'b0;
assign inst_sram_addr  = nextpc;
assign inst_sram_wdata = 32'b0;
assign inst            = inst_sram_rdata;
//inst_sram


                                                   

always @(posedge clk) begin
    if (reset) begin
        pc <= 32'h1bfffffc;     //trick: to make nextpc be 0x1c000000 during reset 
    end
    else
        if(pc_to_next)  pc <= nextpc;
end


nPC u_nPC(
    .currentPC(pc),
    .br_taken(br_taken),
    .br_target(br_target),
    .nextpc(nextpc)
);
//pc

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

//pc

assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                             {{14{i16[15]}}, i16[15:0], 2'b0} ;

assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

assign rj_eq_rd = (rj_value == rkd_value);

assign br_taken = (   inst_beq  &&  rj_eq_rd
                   || inst_bne  && !rj_eq_rd
                   || inst_jirl
                   || inst_bl
                   || inst_b
                  ) && valid;
assign IF_fresh = br_taken;////////////////////////////////////////////666666666666666666666666666666666666666666666666666
assign br_target = (inst_beq || inst_bne || inst_bl || inst_b) ? (PC_ID + br_offs) :
                                                   /*inst_jirl*/ (rj_value + jirl_offs);



//译码

ID u_ID(

    .inst(inst_ID),

    .inst_add_w(inst_add_w),
    .inst_sub_w(inst_sub_w),
    .inst_slt(inst_slt),
    .inst_sltu(inst_sltu),
    .inst_nor(inst_nor),
    .inst_and(inst_and),
    .inst_or(inst_or),
    .inst_xor(inst_xor),
    .inst_slli_w(inst_slli_w),
    .inst_srli_w(inst_srli_w),
    .inst_srai_w(inst_srai_w),
    .inst_addi_w(inst_addi_w),
    .inst_ld_w(inst_ld_w),
    .inst_st_w(inst_st_w),
    .inst_jirl(inst_jirl),
    .inst_b(inst_b),
    .inst_bl(inst_bl),
    .inst_beq(inst_beq),
    .inst_bne(inst_bne),
    .inst_lu12i_w(inst_lu12i_w),

    .need_ui5(need_ui5),
    .need_si12(need_si12),
    .need_si16(need_si16),
    .need_si20(need_si20),
    .need_si26(need_si26),
    .src2_is_4(src2_is_4),
    .alu_op(alu_op),

    .rd(rd),
    .rj(rj),
    .rk(rk),
    .i12(i12),
    .i20(i20),
    .i16(i16),
    .i26(i26)
);
//译码


//访问regfile

assign rf_or_mem  = inst_ld_w;
assign dst_is_r1     = inst_bl;
assign gr_we         = ~inst_st_w & ~inst_beq & ~inst_bne & ~inst_b;

assign dest          = dst_is_r1 ? 5'd1 : rd;
assign src_reg_is_rd = inst_beq | inst_bne | inst_st_w;

assign rf_raddr1 = rj;
assign rf_raddr2 = src_reg_is_rd ? rd :rk;


assign imm = src2_is_4 ? 32'h4                      :
             need_si20 ? {i20[19:0], 12'b0}         :
             need_ui5  ? rk                         :
            /*need_si12*/{{20{i12[11]}}, i12[11:0]} ;


assign src1_is_pc    = inst_jirl | inst_bl;
assign src2_is_imm   = inst_slli_w |
                       inst_srli_w |
                       inst_srai_w |
                       inst_addi_w |
                       inst_ld_w   |
                       inst_st_w   |
                       inst_lu12i_w|
                       inst_jirl   |
                       inst_bl     ;

assign rj_value  = rf_rdata1;
assign rkd_value = rf_rdata2;

assign alu_src1 = src1_is_pc  ? PC_ID : rj_value;
assign alu_src2 = src2_is_imm ? imm : rkd_value;

//ID/EXE寄存器
wire id_to_exe_en = 1'b1;
wire br_taken_EXE, rf_we_EXE, rf_or_mem_EXE, mem_en_EXE;
wire [31:0] br_target_EXE, rkd_value_EXE, alu_src1_EXE, alu_src2_EXE, PC_EXE;
wire [4:0] rf_waddr_EXE;
wire [11:0] alu_op_EXE;
wire [3:0] data_sram_we_EXE;

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

wire exe_mem_en, rf_we_MEM, br_taken_MEM, rf_or_mem_MEM, mem_en_MEM;
wire [3:0] data_sram_we_MEM;
wire [31:0] rkd_value_MEM, alu_result_MEM, br_target_MEM, PC_MEM;
wire [4:0] rf_waddr_MEM;
assign exe_mem_en = 1'b1;

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


assign mem_result   = data_sram_rdata;
assign final_result = rf_or_mem_MEM ? mem_result : alu_result_MEM;/////////////////////////666666666666666666666666666666666666666

assign rf_we    = gr_we && valid;
assign rf_waddr = dest;
assign rf_wdata = final_result;
//data_sram

assign mem_we        = inst_st_w;

assign data_sram_we    = {4{mem_en_EXE && valid}};
assign data_sram_addr  = alu_result;//这里会取旧值，所以应该前递
assign data_sram_wdata = rkd_value_EXE;//理由同上
//data_sram

wire rf_we_WB, mem_wb_en;
wire [4:0] rf_waddr_WB;
wire [31:0] rf_wdata_WB, PC_WB;

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


regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we_WB ),
    .waddr  (rf_waddr_WB ),
    .wdata  (rf_wdata_WB )
    );
//访问regfile

// debug info generate
assign debug_wb_pc       = PC_WB;
assign debug_wb_rf_we    = {4{rf_we_WB}};  
assign debug_wb_rf_wnum  = rf_waddr_WB;
assign debug_wb_rf_wdata = rf_wdata_WB;
// debug info generate

assign inst_sram_en = 1'b1;
assign data_sram_en = 1'b1;

endmodule
