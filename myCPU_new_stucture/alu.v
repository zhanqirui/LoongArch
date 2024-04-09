module alu(
  input  wire [27:0] alu_op,
  input  wire [31:0] alu_src1,
  input  wire [31:0] alu_src2,
  output wire [31:0] alu_result
);

wire op_add;   //add operation
wire op_sub;   //sub operation
wire op_slt;   //signed compared and set less than
wire op_sltu;  //unsigned compared and set less than
wire op_and;   //bitwise and
wire op_nor;   //bitwise nor
wire op_or;    //bitwise or
wire op_xor;   //bitwise xor
wire op_sll;   //logic left shift
wire op_srl;   //logic right shift
wire op_sra;   //arithmetic right shift
wire op_lui;   //Load Upper Immediate
wire op_pcaddu;
wire op_slti;
wire op_sltui;
wire op_andi;
wire op_ori;
wire op_xori;
wire op_sllw;
wire op_sraw;
wire op_srlw;
wire op_div;
wire op_divu;
wire op_mulw;
wire op_mulhw;
wire op_mulhwu;
wire op_mod;
wire op_modu;
// control code decomposition
assign op_add  = alu_op[ 0];
assign op_sub  = alu_op[ 1];
assign op_slt  = alu_op[ 2];
assign op_sltu = alu_op[ 3];
assign op_and  = alu_op[ 4];
assign op_nor  = alu_op[ 5];
assign op_or   = alu_op[ 6];
assign op_xor  = alu_op[ 7];
assign op_sll  = alu_op[ 8];
assign op_srl  = alu_op[ 9];
assign op_sra  = alu_op[10];
assign op_lui  = alu_op[11];
assign op_pcaddu = alu_op[12];
assign op_slti = alu_op[13];
assign op_sltui= alu_op[14];
assign op_andi = alu_op[15];
assign op_ori  = alu_op[16];
assign op_xori = alu_op[17];
assign op_sllw = alu_op[18];
assign op_sraw = alu_op[19];
assign op_srlw = alu_op[20];
assign op_div  = alu_op[21];
assign op_divu = alu_op[22];
assign op_mulw = alu_op[23];
assign op_mulhw= alu_op[24];
assign op_mulhwu= alu_op[25];
assign op_mod  = alu_op[26];
assign op_modu = alu_op[27];


wire [31:0] add_sub_result;
wire [31:0] slt_result;
wire [31:0] sltu_result;
wire [31:0] and_result;
wire [31:0] nor_result;
wire [31:0] or_result;
wire [31:0] xor_result;
wire [31:0] lui_result;
wire [31:0] sll_result;
wire [63:0] sr64_result;
wire [31:0] sr_result;
wire [31:0] pcaddu_result;
wire [31:0] slti_result;
wire [31:0] sltui_result;
wire [31:0] div_result;
wire [31:0]divu_result;
wire [31:0]f_div_result;
wire [63:0] mul_result;
wire [63:0] umul_result;
wire [31:0] f_mul_result;
wire [31:0] mod_result;
wire [31:0] umod_result;
wire [31:0] f_mod_result;
// 32-bit adder
wire [31:0] adder_a;
wire [31:0] adder_b;
wire        adder_cin;
wire [31:0] adder_result;
wire        adder_cout;

assign adder_a   = alu_src1;
assign adder_b   = (op_sub | op_slt | op_sltu) ? ~alu_src2 : alu_src2;  //src1 - src2 rj-rk
assign adder_cin = (op_sub | op_slt | op_sltu) ? 1'b1      : 1'b0;
assign {adder_cout, adder_result} = adder_a + adder_b + adder_cin;

// ADD, SUB,PCADDU result
assign add_sub_result = adder_result;
assign pcaddu_result = adder_result;

// SLT result
assign slt_result[31:1] = 31'b0;   //rj < rk 1
assign slt_result[0]    = (alu_src1[31] & ~alu_src2[31])
                        | ((alu_src1[31] ~^ alu_src2[31]) & adder_result[31]);

// SLTU result
assign sltu_result[31:1] = 31'b0;
assign sltu_result[0]    = ~adder_cout;

// bitwise operation
assign and_result = alu_src1 & alu_src2;
assign or_result  = alu_src1 | alu_src2;
assign nor_result = ~or_result;
assign xor_result = alu_src1 ^ alu_src2;
assign lui_result = alu_src2;

//乘除
assign div_result = $signed(alu_src1) / $signed(alu_src2);
assign divu_result= $unsigned(alu_src1) / $unsigned(alu_src2);
assign f_div_result= op_div ? div_result : divu_result;

assign mul_result = $signed(alu_src1) * $signed(alu_src2);
assign umul_result = $unsigned(alu_src1) * $unsigned(alu_src2);
assign f_mul_result = op_mulhwu ? umul_result[63:32] : (op_mulw ? mul_result[31:0] : mul_result[63:32]);

assign mod_result = $signed(alu_src1) % $signed(alu_src2);
assign umod_result= $unsigned(alu_src1) % $unsigned(alu_src2);
assign f_mod_result=op_mod ? mod_result : umod_result;
// SLL result
assign sll_result = alu_src1 << alu_src2[4:0];   //rj << ui5

// SRL, SRA result
assign sr64_result = {{32{(op_sra|op_sraw) & alu_src1[31]}}, alu_src1[31:0]} >> alu_src2[4:0]; //rj >> i5

assign sr_result   = sr64_result[31:0];

assign slti_result =(alu_src1[31] == alu_src2[31]) ? ((alu_src1 >= alu_src2) ? 0 : 1) : (alu_src1[31] == 0 ? 0 : 1);
assign sltui_result = alu_src1 < alu_src2 ? 1 : 0;



// final result mux
assign alu_result = ({32{op_add|op_sub}} & add_sub_result)
                  | ({32{op_pcaddu }} & pcaddu_result)
                  | ({32{op_slt       }} & slt_result)
                  | ({32{op_sltu      }} & sltu_result)
                  | ({32{op_and | op_andi}} & and_result)
                  | ({32{op_nor       }} & nor_result)
                  | ({32{op_or | op_ori }} & or_result)
                  | ({32{op_xor|op_xori}} & xor_result)
                  | ({32{op_lui       }} & lui_result)
                  | ({32{op_sll | op_sllw}} & sll_result)
                  | ({32{op_srl | op_sra|op_sraw|op_srlw}} & sr_result)
                  | ({32{op_slti}} & slti_result)
                  |({32{op_sltui}} & sltui_result)
                  |({32{op_div | op_divu}} & f_div_result)
                  |({32{op_mulw | op_mulhw | op_mulhwu}} & f_mul_result)
                  |({32{op_mod | op_modu}} & f_mod_result);

endmodule
