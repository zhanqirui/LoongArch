module ID_stage(

input wire [31:0] inst,pc,
input clk, valid,rf_we_WB,
input [4:0] rf_waddr_WB,
input [31:0] rf_wdata_WB,

output br_taken, rf_or_mem, mem_we, rf_we,IF_fresh,
output [31:0] rkd_value, br_target, alu_src1, alu_src2,
output [4:0] dest,
output wire [11:0] alu_op
);

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

wire [ 5:0] op_31_26;
wire [ 3:0] op_25_22;
wire [ 1:0] op_21_20;
wire [ 4:0] op_19_15;

assign op_31_26  = inst[31:26];
assign op_25_22  = inst[25:22];
assign op_21_20  = inst[21:20];
assign op_19_15  = inst[19:15];

wire [63:0] op_31_26_d;
wire [15:0] op_25_22_d;
wire [ 3:0] op_21_20_d;
wire [31:0] op_19_15_d;

wire rj_eq_rd, dst_is_r1, gr_we, src_reg_is_rd, src1_is_pc, src2_is_imm;
wire [31:0] rj_value, jirl_offs, br_offs,imm, rf_rdata1, rf_rdata2;
wire [4:0] rf_raddr1, rf_raddr2;

decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));

assign inst_add_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
assign inst_sub_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
assign inst_slt    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
assign inst_sltu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
assign inst_nor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
assign inst_and    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
assign inst_or     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
assign inst_xor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
assign inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
assign inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];
assign inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
assign inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
assign inst_jirl   = op_31_26_d[6'h13];
assign inst_b      = op_31_26_d[6'h14];
assign inst_bl     = op_31_26_d[6'h15];
assign inst_beq    = op_31_26_d[6'h16];
assign inst_bne    = op_31_26_d[6'h17];
assign inst_lu12i_w= op_31_26_d[6'h05] & ~inst[25];

//decide which operation alu will excecute
assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w
                    | inst_jirl | inst_bl;
assign alu_op[ 1] = inst_sub_w;
assign alu_op[ 2] = inst_slt;
assign alu_op[ 3] = inst_sltu;
assign alu_op[ 4] = inst_and;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or;
assign alu_op[ 7] = inst_xor;
assign alu_op[ 8] = inst_slli_w;
assign alu_op[ 9] = inst_srli_w;
assign alu_op[10] = inst_srai_w;
assign alu_op[11] = inst_lu12i_w;

//decide which kind of immidiate number would be used
assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
assign need_si12  =  inst_addi_w | inst_ld_w | inst_st_w;
assign need_si16  =  inst_jirl | inst_beq | inst_bne;
assign need_si20  =  inst_lu12i_w;
assign need_si26  =  inst_b | inst_bl;
assign src2_is_4  =  inst_jirl | inst_bl;

assign rd   = inst[ 4: 0];
assign rj   = inst[ 9: 5];
assign rk   = inst[14:10];

assign i12  = inst[21:10];
assign i20  = inst[24: 5];
assign i16  = inst[25:10];
assign i26  = {inst[ 9: 0], inst[25:10]};


// wire rj_eq_rd, dst_is_r1, gr_we, src_reg_is_rd, src1_is_pc, src2_is_imm;
// wire [31:0] rj_value, jirl_offs, br_offs,imm;
// wire [4:0] rf_raddr1, rf_raddr2;
assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};
assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                             {{14{i16[15]}}, i16[15:0], 2'b0};

assign imm = src2_is_4 ? 32'h4                      :
             need_si20 ? {i20[19:0], 12'b0}         :
             need_ui5  ? rk                         :
            {{20{i12[11]}}, i12[11:0]} ;

assign dst_is_r1 = inst_bl;
assign gr_we = ~inst_st_w & ~inst_beq & ~inst_bne & ~inst_b;
assign src_reg_is_rd = inst_beq | inst_bne | inst_st_w;
assign src1_is_pc = inst_jirl | inst_bl;
assign src2_is_imm =   inst_slli_w |
                       inst_srli_w |
                       inst_srai_w |
                       inst_addi_w |
                       inst_ld_w   |
                       inst_st_w   |
                       inst_lu12i_w|
                       inst_jirl   |
                       inst_bl     ;

assign br_taken = (   inst_beq  &&  rj_eq_rd
                || inst_bne  && !rj_eq_rd
                || inst_jirl
                || inst_bl
                || inst_b
                ) && valid;
assign IF_fresh = br_taken;

assign rf_or_mem  = inst_ld_w;
assign mem_we     = inst_st_w;
assign rf_we    = gr_we && valid;
assign br_target = (inst_beq || inst_bne || inst_bl || inst_b) ? (pc + br_offs) :
                                                    (rj_value + jirl_offs);

assign dest          = dst_is_r1 ? 5'd1 : rd;

assign rf_raddr1 = rj;
assign rf_raddr2 = src_reg_is_rd ? rd :rk;

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

assign rj_value  = rf_rdata1;
assign rkd_value = rf_rdata2;

assign rj_eq_rd = (rj_value == rkd_value);

assign alu_src1 = src1_is_pc  ? pc : rj_value;
assign alu_src2 = src2_is_imm ? imm : rkd_value;



//后续要使用的信号：br_taken, rf_or_mem, mem_we, rf_we, 
// rkd_value, br_target, alu_src1, alu_src2
// dest
/*
wire ID_en;// not used
wire write_back_en;

assign write_back_en = ~(inst_b | inst_bne | inst_beq | inst_st_w);

assign ID_en = 1'b1;

   assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                             {{14{i16[15]}}, i16[15:0], 2'b0} ;
   assign rj_value  = rf_rdata1;
   assign rkd_value = rf_rdata2;
   assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

   assign rj_eq_rd = (rj_value == rkd_value);

   assign br_taken = (   inst_beq  &&  rj_eq_rd
                   || inst_bne  && !rj_eq_rd
                   || inst_jirl
                   || inst_bl
                   || inst_b
                  ) && valid;
   assign br_target = (inst_beq || inst_bne || inst_bl || inst_b) ? (pc + br_offs) :
                                                    (rj_value + jirl_offs);

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
            {{20{i12[11]}}, i12[11:0]} ;


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



assign alu_src1 = src1_is_pc  ? pc : rj_value;
assign alu_src2 = src2_is_imm ? imm : rkd_value;
assign mem_we        = inst_st_w;

*/


endmodule