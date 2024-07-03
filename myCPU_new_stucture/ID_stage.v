`include "mycpu.h"

module id_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          es_allowin    ,
    input                          es_to_ds_load_op,
    input   [4:0]   es_to_ds_dest,
    input   [4:0]   ms_to_ds_dest,
    input   [4:0]   ws_to_ds_dest,

    input           es_to_ds_is_exc,
    input           ms_to_ds_is_exc,
    input           ws_to_ds_is_exc,
    input   [`MS_TO_DS_EXBUS_WD - 1 : 0] ms_to_ds_exbus,
    input   [31:0]  es_to_ds_result,
    input   [31:0]  ms_to_ds_result,
    input   [31:0]  ws_to_ds_result,

    input   [31:0] es_pc,
    input          ALE_exc,
    input          invtlb_op_exc,
    input   [31:0] data_sram_addr,
    output                         ds_allowin    ,
    //from fs
    input                          fs_to_ds_valid,
    input  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus  ,
    //to es
    output                         ds_to_es_valid,
    output [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    output [`CSR_TO_EXE_BUS_WD-1:0] csr_to_exe_bus,
    output [`CSR_TO_MEM_BUS_WD-1:0] csr_to_mem_bus,
    //to fs
    output [`BR_BUS_WD       -1:0] br_bus        ,
    output [`CSR_BUS_WD       -1:0] ds_to_fs_csr_bus,
    //to rf: for write back
    input  [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus,
    // from tlb
    input [`TLBSRH_TO_CSR_BUS_WD-1:0] tlbsrh_to_csr_bus,
    input [`TLBRD_TO_CSR_BUS_WD-1:0] tlbrd_to_csr_bus
);

wire        br_taken;
wire [31:0] br_target;

wire [31:0] ds_pc;
wire [31:0] ds_inst;

reg         ds_valid   ;
wire        ds_ready_go;

wire [27:0] alu_op;

wire [4:0]  load_op;
wire        src1_is_pc;
wire        src2_is_imm;
wire        res_from_mem;
wire        dst_is_r1;
wire        gr_we;
wire        mem_we;
// !csr
wire [1:0]  ws_csr_we;
wire [13:0] ws_csr_num;
wire [31:0] ws_rj_value;

wire [31:0] pc_to_badv;
wire [31:0] pc_to_era;
wire Addr_exc;

wire [1:0]  csr_we;//CSR写使能信号
wire [13:0] csr_num;//CSR寄存器编号
wire        res_from_csr;//由于csrwr和csrxchg会将CSR的信息记录至rd中，所以在流水线中，需要有一个这个选择exe阶段写回id阶段的数据
wire [31:0] csr_rdata;
wire [31:0] csr_wdata;
wire [14:0] syscall_code;
wire [14:0] break_code;

wire        is_ret;//记录是否需要返回
wire        is_exc; //记录是否异常！

wire [31:0] csr_era;
wire [31:0] csr_eentry;
wire        is_following_exc;
wire [5:0]  Ecode;
wire [8:0]  EsubCode;

wire        ADEF_exc;
wire        INE_exc;

wire  [31:0] fms_pc_to_era;
wire  [31:0] fms_pc_to_badv;
wire  fms_Addr_exc;
wire  [5:0] fms_Ecode;
wire  [8:0] fms_EsubCode;


wire br_exc, era_exc;
wire dest_is_rj;

wire need_cnt_l;
wire need_cnt_h;
wire need_cnt_id;
wire        need_interrupt;


wire        src_reg_is_rd;
wire [4: 0] dest;
wire [31:0] rj_value;
wire [31:0] rkd_value;
wire [31:0] imm;
wire [31:0] br_offs;
wire [31:0] jirl_offs;


wire [ 5:0] op_31_26;
wire [ 3:0] op_25_22;
wire [ 1:0] op_21_20;
wire [ 4:0] op_19_15;
wire [ 4:0] op_9_5;
wire [ 4:0] op_14_10;
wire [ 4:0] op_4_0;
wire [ 4:0] rd;
wire [ 4:0] rj;
wire [ 4:0] rk;
wire [11:0] i12;
wire [19:0] i20;
wire [15:0] i16;
wire [25:0] i26;

wire [63:0] op_31_26_d;
wire [15:0] op_25_22_d;
wire [ 3:0] op_21_20_d;
wire [31:0] op_19_15_d;
wire [31:0] op_9_5_d;
wire [31:0] op_4_0_d;
wire [31:0] op_14_10_d;

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
wire        inst_pcaddu;

//exp10添加指令
wire        inst_slti;
wire        inst_sltui;
wire        inst_andi;
wire        inst_ori;
wire        inst_xori;
wire        inst_sllw;
wire        inst_sraw;
wire        inst_srlw;
wire        inst_div;
wire        inst_divu;
wire        inst_mulw;
wire        inst_mulhw;
wire        inst_mulhwu;
wire        inst_mod;
wire        inst_modu;

//!exp11添加指令
wire        inst_blt;
wire        inst_bge;
wire        inst_bltu;
wire        inst_bgeu;
wire        inst_ld_b;
wire        inst_ld_h;
wire        inst_ld_bu;
wire        inst_ld_hu;
wire        inst_st_b;
wire        inst_st_h;

//! exp12添加指令
wire inst_csrrd;
wire inst_csrwr;
wire inst_csrxchg;
wire inst_ertn;
wire inst_syscall;

//!exp13添加指令
wire inst_break;
wire inst_rdcntvl_w;
wire inst_rdcntvh_w;
wire inst_rdcntid;

// !exp18添加指令
wire inst_tlbsrch;
wire inst_tlbrd;
wire inst_tlbwr;
wire inst_tlbfill;
wire inst_invtlb;
wire invtlb_valid;
wire [4:0] invtlb_op;
wire [2:0] tlbop;

wire        need_ui5;
wire        need_si12;
wire        need_ui12;
wire        need_si16;
wire        need_si20;
wire        need_si26;
wire        src2_is_4;

wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;

wire        rf_we   ;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;

wire [2:0] st_op;

assign op_31_26  = ds_inst[31:26];
assign op_25_22  = ds_inst[25:22];
assign op_21_20  = ds_inst[21:20];
assign op_19_15  = ds_inst[19:15];
assign op_14_10  = ds_inst[14:10];
assign op_9_5    = ds_inst[9:5];
assign op_4_0    = ds_inst[4:0];

assign rd   = ds_inst[ 4: 0];
assign rj   = ds_inst[ 9: 5];
assign rk   = ds_inst[14:10];
assign csr_num = inst_rdcntid ? 14'h40 : ds_inst[23 : 10];


assign i12  = ds_inst[21:10];
assign i20  = ds_inst[24: 5];
assign i16  = ds_inst[25:10];
assign i26  = {ds_inst[ 9: 0], ds_inst[25:10]};

decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));
decoder_5_32 u_dec5(.in(op_14_10), .out(op_14_10_d));
decoder_5_32 u_dec6(.in(op_4_0), .out(op_4_0_d));
decoder_5_32 u_dec4(.in(op_9_5 ), .out(op_9_5_d ));


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
assign inst_ld_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h1];
assign inst_ld_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h0];
assign inst_ld_hu   = op_31_26_d[6'h0a] & op_25_22_d[4'h9];
assign inst_ld_bu   = op_31_26_d[6'h0a] & op_25_22_d[4'h8];

assign inst_st_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h4];
assign inst_st_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h5];
assign inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];


assign inst_jirl   = op_31_26_d[6'h13];
assign inst_b      = op_31_26_d[6'h14];
assign inst_bl     = op_31_26_d[6'h15];
assign inst_beq    = op_31_26_d[6'h16];
assign inst_bne    = op_31_26_d[6'h17];
assign inst_blt    = op_31_26_d[6'h18];
assign inst_bge    = op_31_26_d[6'h19];
assign inst_bltu   = op_31_26_d[6'h1a];
assign inst_bgeu   = op_31_26_d[6'h1b];

assign inst_lu12i_w= op_31_26_d[6'h05] & ~ds_inst[25];
assign inst_pcaddu = op_31_26_d[6'h07] & ~ds_inst[25];

assign inst_slti   = op_31_26_d[6'h00] & op_25_22_d[4'h08];
assign inst_sltui  = op_31_26_d[6'h00] & op_25_22_d[4'h09];
assign inst_andi   = op_31_26_d[6'h00] & op_25_22_d[4'h0d];
assign inst_ori    = op_31_26_d[6'h00] & op_25_22_d[4'h0e];
assign inst_xori   = op_31_26_d[6'h00] & op_25_22_d[4'h0f];
assign inst_sllw   = op_31_26_d[6'h00] & op_25_22_d[4'h00] & op_21_20_d[2'h1] & op_19_15_d[5'h0e];
assign inst_sraw   = op_31_26_d[6'h00] & op_25_22_d[4'h00] & op_21_20_d[2'h1] & op_19_15_d[5'h10];
assign inst_srlw   = op_31_26_d[6'h00] & op_25_22_d[4'h00] & op_21_20_d[2'h1] & op_19_15_d[5'h0f];
assign inst_div    = op_31_26_d[6'h00] & op_25_22_d[4'h00] & op_21_20_d[2'h2] & op_19_15_d[5'h00];
assign inst_divu   = op_31_26_d[6'h00] & op_25_22_d[4'h00] & op_21_20_d[2'h2] & op_19_15_d[5'h02];
assign inst_mulw   = op_31_26_d[6'h00] & op_25_22_d[4'h00] & op_21_20_d[2'h1] & op_19_15_d[5'h18];
assign inst_mulhw  = op_31_26_d[6'h00] & op_25_22_d[4'h00] & op_21_20_d[2'h1] & op_19_15_d[5'h19];
assign inst_mulhwu = op_31_26_d[6'h00] & op_25_22_d[4'h00] & op_21_20_d[2'h1] & op_19_15_d[5'h1a];
assign inst_mod    = op_31_26_d[6'h00] & op_25_22_d[4'h00] & op_21_20_d[2'h2] & op_19_15_d[5'h01];
assign inst_modu   = op_31_26_d[6'h00] & op_25_22_d[4'h00] & op_21_20_d[2'h2] & op_19_15_d[5'h03];


assign inst_csrrd = op_31_26_d[6'h01] & ds_inst[25:24] == 2'b0 & op_9_5_d[5'h00];
assign inst_csrwr = op_31_26_d[6'h01] & ds_inst[25:24] == 2'b0 & op_9_5_d[5'h01];
assign inst_csrxchg = op_31_26_d[6'h01] & ds_inst[25:24] == 2'b0 & ((!op_9_5_d[5'h00]) & (!op_9_5_d[5'h01]));
assign inst_ertn = ds_inst == 32'h06483800;
assign inst_syscall = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h16];
assign inst_break = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h14];
assign inst_rdcntvl_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & op_14_10_d[5'h18] & op_9_5_d[5'h0];
assign inst_rdcntvh_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & op_14_10_d[5'h19] & op_9_5_d[5'h0];
assign inst_rdcntid   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & op_14_10_d[5'h18] & op_4_0_d[5'h0];

// wire inst_tlbsrch;
// wire inst_tlbrd;
// wire inst_tlbwr;
// wire inst_tlbfill;
// wire inst_invtlb;
assign inst_tlbsrch = ds_inst == 32'h06482800;
assign inst_tlbrd = ds_inst == 32'h06482c00;
assign inst_tlbwr = ds_inst == 32'h06483000;
assign inst_tlbfill = ds_inst == 32'h06483400;
assign inst_invtlb = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h13];

assign tlbop = inst_tlbsrch ? 3'b001 :
               inst_tlbrd   ? 3'b010 :
               inst_tlbwr   ? 3'b011  :
               inst_tlbfill ? 3'b100 :
               inst_invtlb  ? 3'b101 : 3'b000;

assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_w | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu | inst_st_w | inst_st_b | inst_st_h
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
assign alu_op[12] = inst_pcaddu;

assign alu_op[13] = inst_slti;
assign alu_op[14] = inst_sltui;
assign alu_op[15] = inst_andi;
assign alu_op[16] = inst_ori;
assign alu_op[17] = inst_xori;
assign alu_op[18] = inst_sllw;
assign alu_op[19] = inst_sraw;
assign alu_op[20] = inst_srlw;
assign alu_op[21] = inst_div;
assign alu_op[22] = inst_divu;
assign alu_op[23] = inst_mulw;
assign alu_op[24] = inst_mulhw;
assign alu_op[25] = inst_mulhwu;
assign alu_op[26] = inst_mod;
assign alu_op[27] = inst_modu;


assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
assign need_si12  =  inst_addi_w | inst_ld_w | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu | inst_st_w | inst_st_b | inst_st_h | inst_slti | inst_sltui;
assign need_si16  =  inst_jirl | inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu;
assign need_si20  =  inst_lu12i_w | inst_pcaddu;
assign need_si26  =  inst_b | inst_bl;
assign src2_is_4  =  inst_jirl | inst_bl;
assign need_ui12  =  inst_andi | inst_ori| inst_xori;

assign imm = src2_is_4 ? 32'h4                      :
             need_si20 ? {i20[19:0], 12'b0}         :
             need_ui5  ? rk                         :
             need_ui12 ?{{20'b0}, i12[11:0]}        :
            /*need_si12*/{{20{i12[11]}}, i12[11:0]} ;

assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                              {{14{i16[15]}}, i16[15:0], 2'b0} ;

assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};


//! csrwr
assign src_reg_is_rd = inst_beq | inst_bne | inst_st_w | inst_st_b | inst_st_h | inst_blt | inst_bge | inst_bltu | inst_bgeu | inst_csrwr | inst_csrxchg;

assign src1_is_pc    = inst_jirl | inst_bl | inst_pcaddu;

assign src2_is_imm   = inst_slli_w |
                       inst_srli_w |
                       inst_srai_w |
                       inst_addi_w |
                       inst_ld_w   |
                       inst_ld_b   |
                       inst_ld_h   |
                       inst_ld_bu  |
                       inst_ld_hu  |
                       inst_st_w   |
                       inst_st_b   |
                       inst_st_h   |
                       inst_lu12i_w|
                       inst_jirl   |
                       inst_bl     |
                       inst_pcaddu |
                       inst_slti   |
                       inst_sltui  |
                       inst_andi   |
                       inst_ori    |
                       inst_xori;
assign invtlb_valid = inst_invtlb;
assign invtlb_op = ds_inst[4:0];
assign res_from_mem  = inst_ld_w | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu;
//!csr
assign res_from_csr = inst_csrrd | inst_csrwr | inst_csrxchg | inst_rdcntid;

assign csr_we[0] = inst_csrwr & ~is_following_exc & ds_valid;
assign csr_we[1] = inst_csrxchg & ~is_following_exc & ds_valid;

assign csr_wdata = rkd_value;

//!触发ADEF异常
assign ADEF_exc = era_exc | br_exc;

//!触发INE异常
assign INE_exc =  ~(inst_add_w | inst_sub_w | inst_slt | inst_sltu | inst_nor | inst_and | inst_or | inst_xor | inst_slli_w | inst_srli_w | 
                  inst_srai_w | inst_addi_w | inst_ld_w | inst_st_w | inst_jirl | inst_b | inst_bl | inst_beq | inst_bne | inst_lu12i_w |
                  inst_pcaddu | inst_slti | inst_sltui | inst_andi | inst_ori | inst_xori | inst_sllw | inst_sraw | inst_srlw | inst_div |
                  inst_divu | inst_mulw | inst_mulhw | inst_mulhwu | inst_mod | inst_modu | inst_blt | inst_bge | inst_bltu | inst_bgeu | 
                  inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu | inst_st_b | inst_st_h | inst_csrrd | inst_csrwr | inst_csrxchg | inst_ertn | 
                  inst_syscall | inst_break | inst_rdcntid | inst_rdcntvh_w | inst_rdcntvl_w | inst_tlbsrch | inst_tlbrd | inst_tlbwr | inst_tlbfill |
                  inst_invtlb);


//! 触发BRK异常
assign is_exc = ((inst_break | inst_syscall | ADEF_exc | INE_exc | need_interrupt) & ds_valid) | ALE_exc | invtlb_op_exc;
assign is_ret = inst_ertn & ds_valid;
assign is_following_exc = es_to_ds_is_exc | ms_to_ds_is_exc | ws_to_ds_is_exc | ALE_exc | invtlb_op_exc;

//! 记录异常信息
assign Ecode = inst_syscall ? 6'hb :
               inst_break   ? 6'hc : 
               ADEF_exc     ? 6'h8 : 
               INE_exc      ? 6'hd : 
               ALE_exc      ? 6'h9 : 
               6'h0;
assign EsubCode = 9'h0;

assign syscall_code = ds_inst[14:0];//?暂时不知到有什么用
assign break_code = ds_inst[14:0];//?暂时不知到有什么用

assign dst_is_r1     = inst_bl;
//! 由于这个信号采用的是与非的形式，所以需要区别对待
assign gr_we         = (~inst_st_w & ~inst_st_b & ~inst_st_h & ~inst_beq & ~inst_bne & ~inst_b & ~inst_blt & ~inst_bge & ~inst_bltu & ~inst_bgeu & ~inst_ertn & 
                        ~inst_tlbsrch & ~inst_tlbrd & ~inst_tlbwr & ~inst_tlbfill & ~inst_invtlb) & ds_valid & ~INE_exc & ~is_following_exc;
assign mem_we        = (inst_st_w | inst_st_b | inst_st_h) & ~is_following_exc & ds_valid;
assign dest_is_rj    = inst_rdcntid;
//!bne的dest不存在！！！！因为不写入数据
assign dest          = dst_is_r1 ? 5'd1 : 
                       dest_is_rj ? rj  :
                       gr_we ? rd       
                       : 5'd0;

assign rf_raddr1 = rj;
assign rf_raddr2 = src_reg_is_rd ? rd :rk;
regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );

reg  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus_r;

assign {ds_inst,
        ds_pc  } = fs_to_ds_bus_r;

assign {rf_we   ,  //37:37
        rf_waddr,  //36:32
        rf_wdata   //31:0
       } = ws_to_rf_bus;
       
assign {
        fms_pc_to_era,
        fms_pc_to_badv,
        fms_Addr_exc,
        fms_Ecode,
        fms_EsubCode

} = ms_to_ds_exbus;

assign load_op[0] = inst_ld_w;
assign load_op[1] = inst_ld_b;
assign load_op[2] = inst_ld_h;
assign load_op[3] = inst_ld_bu;
assign load_op[4] = inst_ld_hu;

assign st_op[0] = inst_st_w;
assign st_op[1] = inst_st_h;
assign st_op[2] = inst_st_b;


assign ds_to_es_bus = {alu_op       ,   // 28
                       load_op      ,   // 5
                       st_op        ,   // 3
                       src1_is_pc   ,   // 1
                       src2_is_imm  ,   // 1
                       src2_is_4    ,   // 1
                       gr_we        ,   // 1
                       mem_we       ,   // 1
                       dest         ,   // 5
                       imm          ,   // 32
                       rj_value     ,   // 32
                       rkd_value    ,   // 32
                       ds_pc        ,   // 32
                       res_from_mem ,   // 1
                       res_from_csr ,   // 1
                       csr_rdata,       //32
                       is_exc,           //1
                       need_cnt_l,
                       need_cnt_h,
                       need_cnt_id,
                       pc_to_era,
                       pc_to_badv,
                       Addr_exc,
                       Ecode,
                       EsubCode,
                       invtlb_valid,
                       invtlb_op,
                       tlbop
                    };

    //                     .pc_to_era(pc_to_era),
    // .pc_to_badv(pc_to_badv),
    //     .Addr_exc(Addr_exc),
    // .Ecode(Ecode),
    // .EsubCode(EsubCode)
//csr_we, csr_num, rkd_value
// 1 + 1 + 1 + 64 = 67
assign ds_to_fs_csr_bus = {
                  is_exc,
                  ms_to_ds_is_exc,
                  is_ret,
                  csr_era, 
                  csr_eentry
};

wire rj_eq_es_rd;
wire rj_eq_ms_rd;
wire rk_eq_es_rd;
wire rk_eq_ms_rd;
wire rd_eq_es_rd;
wire rd_eq_ms_rd;

wire src_no_rj;
wire src_no_rk;
wire src_no_rd;
wire rj_wait;
wire rk_wait;
wire rd_wait;
wire no_wait;
wire rj_l_rd;
wire rj_l_rd_u;


assign need_cnt_h = inst_rdcntvh_w;
assign need_cnt_l = inst_rdcntvl_w;
assign need_cnt_id = inst_rdcntid;


//! csr没有rj和rk, 实际上它的rd也不会触发流水线前递，因为不需要使用
assign src_no_rj    = inst_b | inst_bl | inst_lu12i_w | inst_csrrd | inst_csrwr| inst_tlbsrch | inst_tlbrd | inst_tlbwr | inst_tlbfill;
assign src_no_rk    = inst_slli_w | inst_srli_w | inst_srai_w | inst_addi_w | inst_ld_w | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu | inst_st_w | inst_st_b | inst_st_h | inst_jirl | 
                      inst_b | inst_bl | inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu | inst_lu12i_w | inst_slti | inst_sltui| inst_andi |
                      inst_ori| inst_xori | inst_csrrd | inst_csrwr | inst_csrxchg | inst_rdcntvh_w | inst_rdcntvl_w | inst_rdcntid| inst_tlbsrch | inst_tlbrd | inst_tlbwr | inst_tlbfill;
//!别忘记！
assign src_no_rd    = ~inst_st_b & ~inst_st_h & ~inst_st_w & ~inst_beq & ~inst_bne & ~inst_blt & ~inst_bge & ~inst_bltu & ~inst_bgeu & ~inst_csrwr & ~inst_csrxchg;

//! 异常之后的指令，既不需要停顿也不需要前递！
assign rj_wait = ~is_following_exc && ~src_no_rj && (rj != 5'b00000) && ((rj == es_to_ds_dest) || (rj == ms_to_ds_dest) || (rj == ws_to_ds_dest));
assign rk_wait = ~is_following_exc && ~src_no_rk && (rk != 5'b00000) && ((rk == es_to_ds_dest) || (rk == ms_to_ds_dest) || (rk == ws_to_ds_dest));
assign rd_wait = ~is_following_exc && ~src_no_rd && (rd != 5'b00000) && ((rd == es_to_ds_dest) || (rd == ms_to_ds_dest) || (rd == ws_to_ds_dest));

assign no_wait = ~rj_wait & ~rk_wait & ~rd_wait;

assign rj_eq_es_rd = (rj == es_to_ds_dest);
assign rj_eq_ms_rd = (rj == ms_to_ds_dest);

assign rk_eq_es_rd = (rk == es_to_ds_dest);
assign rk_eq_ms_rd = (rk == ms_to_ds_dest);

assign rd_eq_es_rd = (rd == es_to_ds_dest);
assign rd_eq_ms_rd = (rd == ms_to_ds_dest);

assign rj_value  = rj_wait ? (rj_eq_es_rd ? es_to_ds_result :
                              rj_eq_ms_rd ? ms_to_ds_result : ws_to_ds_result)
                            : rf_rdata1;
assign rkd_value = rk_wait ? (rk_eq_es_rd ? es_to_ds_result :
                            rk_eq_ms_rd ? ms_to_ds_result : ws_to_ds_result) : 
                   rd_wait ? (rd_eq_es_rd ? es_to_ds_result :
                            rd_eq_ms_rd ? ms_to_ds_result : ws_to_ds_result) :
                   rf_rdata2;

assign rj_eq_rd = (rj_value == rkd_value);
assign rj_l_rd_u = rj_value < rkd_value;
assign rj_l_rd = ($signed (rj_value) < $signed (rkd_value));



assign br_target = (inst_beq | inst_bne | inst_bl | inst_b | inst_blt | inst_bge | inst_bltu | inst_bgeu) ? ((ds_pc + br_offs) & {32{ds_valid}}) :
                                                   /*inst_jirl*/ ((rj_value + jirl_offs) & {32{ds_valid}});


wire br_stall;//上条是跳转指令，下条是load指令，仅此而已
wire load_stall;
	// es is load and ds is jmp(taken)
//! 此处br_taken可以保证异常传递到之后的流水级时，br_stall为0
assign br_stall   = load_stall & br_taken & ds_valid;
//!异常发生后，上报前的load指令不需要停顿
assign load_stall = ~is_following_exc & es_to_ds_load_op & ( rj_wait |
                                            rk_wait |
                                            rd_wait ); 
assign br_bus       = {br_stall,br_taken,br_target};


// taken signal need to be block too!!!!
assign br_taken = (   inst_beq  &&  rj_eq_rd
                   || inst_bne  && !rj_eq_rd
                   || inst_blt && rj_l_rd
                   || inst_bge && !rj_l_rd
                   || inst_bltu && rj_l_rd_u
                   || inst_bgeu && !rj_l_rd_u
                   || inst_jirl
                   || inst_bl
                   || inst_b
                )  && ds_valid && ~load_stall && ~is_following_exc;
    

assign br_exc = br_taken & (br_target[1:0] != 2'b0);
assign era_exc = is_ret & (csr_era[1:0] != 2'b00);

//?异常处理程序的地址不会错误吗？
assign pc_to_era = br_exc ? br_target : 
                   era_exc ? csr_era  :
                   ALE_exc | invtlb_op_exc ? es_pc    :
                   ds_pc;

assign pc_to_badv =  br_exc ? br_target : 
                     era_exc ? csr_era  :
                     ALE_exc ? data_sram_addr :
                     32'h0;

assign Addr_exc = ADEF_exc | ALE_exc;

csr u_csr(
    .clk(clk),
    .reset(reset),
    .raddr(csr_num),
    .rdata(csr_rdata),
    .ERA(csr_era),
    .EENTRY(csr_eentry),
    .rj_value(rj_value),
    .need_interrupt(need_interrupt),
    .tlbsrh_to_csr_bus(tlbsrh_to_csr_bus),
    .tlbrd_to_csr_bus(tlbrd_to_csr_bus),
    .csr_to_exe_bus(csr_to_exe_bus),
    .csr_to_mem_bus(csr_to_mem_bus),

    .we(csr_we),
    .waddr(csr_num),
    .wdata(csr_wdata),
    .pc_to_era(fms_pc_to_era),
    .pc_to_badv(fms_pc_to_badv),
    .is_ret(is_ret),
    .is_exc(ms_to_ds_is_exc),
    .Addr_exc(fms_Addr_exc),
    .Ecode(fms_Ecode),
    .EsubCode(fms_EsubCode)

);


// csr_we, csr_num, rkd_value
assign ds_ready_go    = ds_valid & ~load_stall;
assign ds_allowin     = !ds_valid || (ds_ready_go && es_allowin);//本身无效或者传递给下一个阶段
assign ds_to_es_valid = ds_valid && ds_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ds_valid <= 1'b0;
    end
    else if (ds_allowin) begin
        ds_valid <= fs_to_ds_valid;
    end
end

always@(posedge clk)
    if(reset)
        fs_to_ds_bus_r <= 0;
    else if (fs_to_ds_valid && ds_allowin) begin
        fs_to_ds_bus_r <= fs_to_ds_bus;
    end

endmodule
