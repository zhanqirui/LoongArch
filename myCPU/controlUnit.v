module controlUnit (
    input wire        clk,
    input wire        reset,

    input wire        inst_add_w,
    input wire        inst_sub_w,
    input wire        inst_slt,
    input wire        inst_sltu,
    input wire        inst_nor,
    input wire        inst_and,
    input wire        inst_or,
    input wire        inst_xor,
    input wire        inst_slli_w,
    input wire        inst_srli_w,
    input wire        inst_srai_w,
    input wire        inst_addi_w,
    input wire        inst_ld_w,
    input wire        inst_st_w,
    input wire        inst_jirl,
    input wire        inst_b,
    input wire        inst_bl,
    input wire        inst_beq,
    input wire        inst_bne,
    input wire        inst_lu12i_w,

    output wire pc_to_next,
    output wire alu_en,
    output wire ID_en,
    output wire write_back_en,
    output wire mem_access_en
);
    
    parameter IF = 3'b000;
    parameter ID = 3'b001;
    parameter EXE_mem = 3'b010;
    parameter EXE_wb = 3'b011;
    parameter EXE_if = 3'b100;
    parameter MEM = 3'b101;
    parameter WB = 3'b110;

    wire [2:0] ID_to_EXE;
    // 001->mem, 010->wb, 100->if, one-hot
    assign ID_to_EXE[0] = inst_ld_w 
                        | inst_st_w;

    assign ID_to_EXE[1] = inst_add_w
                        | inst_sub_w
                        | inst_slt
                        | inst_sltu
                        | inst_nor
                        | inst_and
                        | inst_or
                        | inst_xor
                        | inst_slli_w
                        | inst_srli_w
                        | inst_srai_w
                        | inst_addi_w
                        | inst_jirl
                        | inst_lu12i_w
                        | inst_bl;

    assign ID_to_EXE[2] = inst_b
                        | inst_beq
                        | inst_bne;

    reg [2:0] nextState;
    reg [2:0] state;

    always@(posedge clk) begin
        if(reset)   state <= IF;
        else state <= nextState;
    end

    always@(*) begin
        case(state)
            IF: nextState <= ID;
            ID: nextState <= ID_to_EXE[0] ? EXE_mem :
                            (ID_to_EXE[1] ? EXE_wb :
                            /*ID_to_EXE[2] ?*/ EXE_if );
            EXE_mem: nextState <= MEM;
            EXE_wb: nextState <= WB;
            EXE_if: nextState <= IF;
            MEM: nextState <= (inst_ld_w) ? WB : IF;
            WB: nextState <= IF;
            default : nextState <= IF;
        endcase
    end
    


    // Add control signals
    assign pc_to_next = (state == IF);
    assign ID_en = (state == ID);
    assign alu_en = (state == EXE_if) || (state == EXE_mem) || (state == EXE_wb);
    assign mem_access_en = (state == MEM);
    assign write_back_en = (state == WB);

endmodule