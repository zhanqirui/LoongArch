module tlb #(
    parameter integer TLBNUM = 16
)(
    input wire clk,

    input wire invtlb_valid,
    input wire [4:0] invtlb_op,

    // Search port 0
    input wire [18:0] s0_vppn,
    input wire s0_va_bit12,
    input wire [9:0] s0_asid,
    output wire s0_found,
    output wire [$clog2(TLBNUM)-1:0] s0_index,
    output wire [19:0] s0_ppn,
    output wire [5:0] s0_ps,
    output wire [1:0] s0_plv,
    output wire [1:0] s0_mat,
    output wire s0_d,
    output wire s0_v,

    // Search port 1
    input wire [18:0] s1_vppn,
    input wire s1_va_bit12,
    input wire [9:0] s1_asid,
    output wire s1_found,
    output wire [$clog2(TLBNUM)-1:0] s1_index,
    output wire [19:0] s1_ppn,
    output wire [5:0] s1_ps,
    output wire [1:0] s1_plv,
    output wire [1:0] s1_mat,
    output wire s1_d,
    output wire s1_v,

    // Write port
    input wire we,
    input wire [$clog2(TLBNUM)-1:0] w_index,
    input wire w_e,
    input wire [18:0] w_vppn,
    input wire [5:0] w_ps,
    input wire [9:0] w_asid,
    input wire w_g,
    input wire [19:0] w_ppn0,
    input wire [1:0] w_plv0,
    input wire [1:0] w_mat0,
    input wire w_d0,
    input wire w_v0,
    input wire [19:0] w_ppn1,
    input wire [1:0] w_plv1,
    input wire [1:0] w_mat1,
    input wire w_d1,
    input wire w_v1,

    // Read port
    input wire [$clog2(TLBNUM)-1:0] r_index,
    output wire r_e,
    output wire [18:0] r_vppn,
    output wire [5:0] r_ps,
    output wire [9:0] r_asid,
    output wire r_g,
    output wire [19:0] r_ppn0,
    output wire [1:0] r_plv0,
    output wire [1:0] r_mat0,
    output wire r_d0,
    output wire r_v0,
    output wire [19:0] r_ppn1,
    output wire [1:0] r_plv1,
    output wire [1:0] r_mat1,
    output wire r_d1,
    output wire r_v1
);

reg [18:0] tlb_vppn  [TLBNUM - 1 : 0];
reg [5:0]  tlb_ps    [TLBNUM - 1 : 0];
reg        tlb_g     [TLBNUM - 1 : 0];
reg [ 9:0] tlb_asid  [TLBNUM - 1 : 0];
reg        tlb_e     [TLBNUM - 1 : 0];
reg [19:0] tlb_ppn0  [TLBNUM - 1 : 0];
reg [ 1:0] tlb_plv0  [TLBNUM - 1 : 0];
reg [ 1:0] tlb_mat0  [TLBNUM - 1 : 0];
reg        tlb_d0    [TLBNUM - 1 : 0];
reg        tlb_v0    [TLBNUM - 1 : 0];
reg [19:0] tlb_ppn1  [TLBNUM - 1 : 0];
reg [ 1:0] tlb_plv1  [TLBNUM - 1 : 0];
reg [ 1:0] tlb_mat1  [TLBNUM - 1 : 0];
reg        tlb_d1    [TLBNUM - 1 : 0];
reg        tlb_v1    [TLBNUM - 1 : 0];
wire  [TLBNUM - 1 : 0]         match0;    
wire  [TLBNUM - 1 : 0]         match1;    

integer i;

// Read port
assign r_e    = tlb_e[r_index];      
assign r_vppn = r_e ? tlb_vppn[r_index] : 0;
assign r_ps   = r_e ?  tlb_ps[r_index] : 0;
assign r_asid = r_e ?  tlb_asid[r_index] : 0;
assign r_g    = r_e ?  tlb_g[r_index] : 0;
assign r_ppn0 = r_e ?  tlb_ppn0[r_index] : 0;
assign r_plv0 = r_e ?   tlb_plv0[r_index] : 0;
assign r_mat0 = r_e ?   tlb_mat0[r_index] : 0;
assign r_d0   = r_e ?   tlb_d0[r_index] : 0;
assign r_v0   = r_e ?   tlb_v0[r_index] : 0;
assign r_ppn1 = r_e ?   tlb_ppn1[r_index] : 0;
assign r_plv1 = r_e ?   tlb_plv1[r_index] : 0;
assign r_mat1 = r_e ?   tlb_mat1[r_index] : 0;
assign r_d1   = r_e ?   tlb_d1[r_index] : 0;
assign r_v1   = r_e ?   tlb_v1[r_index] : 0;


//write port
always @(posedge clk) begin
    if (we) begin
        tlb_vppn[w_index] <= w_vppn;
        tlb_ps[w_index] <= w_ps;
        tlb_g[w_index] <= w_g;
        tlb_asid[w_index] <= w_asid;
        tlb_e[w_index] <= w_e; 
        tlb_ppn0[w_index] <= w_ppn0;
        tlb_plv0[w_index] <= w_plv0;
        tlb_mat0[w_index] <= w_mat0;
        tlb_d0[w_index] <= w_d0;
        tlb_v0[w_index] <= w_v0;
        tlb_ppn1[w_index] <= w_ppn1;
        tlb_plv1[w_index] <= w_plv1;
        tlb_mat1[w_index] <= w_mat1;
        tlb_d1[w_index] <= w_d1;
        tlb_v1[w_index] <= w_v1;
    end
    else if(invtlb_valid)begin
        if(invtlb_op == 5'b0 || invtlb_op == 5'b1)begin
            for(i = 0; i < 16; i = i + 1)begin
                tlb_e[i] <= 0;
            end
        end
        else if(invtlb_op == 5'h2)begin
            for(i = 0;i < 16;i = i + 1)begin
                if(tlb_g[i])
                    tlb_e[i] <= 0;
            end
        end
        else if(invtlb_op == 5'h3)begin
            for(i = 0;i < 16;i = i + 1)begin
                if(~tlb_g[i])
                    tlb_e[i] <= 0;
            end
        end
        else if(invtlb_op == 5'h4)begin
            for(i = 0;i < 16;i = i + 1)begin
                if(tlb_g[i] == 0 && tlb_asid[i] == s1_asid)
                    tlb_e[i] <= 0;
            end
        end
        else if(invtlb_op == 5'h5)begin
            for(i = 0;i < 16;i = i + 1)begin
                if(tlb_g[i] == 0 && tlb_asid[i] == s1_asid && tlb_vppn[i] == s1_vppn)
                    tlb_e[i] <= 0;
            end
        end
        else if(invtlb_op == 5'h6)begin
            for(i = 0;i < 16;i = i + 1)begin
                if((tlb_g[i] == 1'b1 || tlb_asid[i] == s1_asid) && tlb_vppn[i] == s1_vppn)
                    tlb_e[i] <= 0;
            end
        end
        
    end

end

wire is_match0;

//search port
assign match0[0]  = tlb_e[0] & (s0_vppn[18:10] == tlb_vppn[0][18:10])  && ((s0_asid == tlb_asid[0])  || tlb_g[0]) && (tlb_ps[0] == 6'd21  || s0_vppn[9:0]==tlb_vppn[ 0][9:0]);
assign match0[1]  = tlb_e[1] & (s0_vppn[18:10] == tlb_vppn[1][18:10])  && ((s0_asid == tlb_asid[1])  || tlb_g[1]) && (tlb_ps[1] == 6'd21  || s0_vppn[9:0]==tlb_vppn[ 1][9:0]);
assign match0[2]  = tlb_e[2] & (s0_vppn[18:10] == tlb_vppn[2][18:10])  && ((s0_asid == tlb_asid[2])  || tlb_g[2]) && (tlb_ps[2] == 6'd21  || s0_vppn[9:0]==tlb_vppn[ 2][9:0]);
assign match0[3]  = tlb_e[3] & (s0_vppn[18:10] == tlb_vppn[3][18:10])  && ((s0_asid == tlb_asid[3])  || tlb_g[3]) && (tlb_ps[3] == 6'd21  || s0_vppn[9:0]==tlb_vppn[ 3][9:0]);
assign match0[4]  = tlb_e[4] & (s0_vppn[18:10] == tlb_vppn[4][18:10])  && ((s0_asid == tlb_asid[4])  || tlb_g[4]) && (tlb_ps[4] == 6'd21  || s0_vppn[9:0]==tlb_vppn[ 4][9:0]);
assign match0[5]  = tlb_e[5] & (s0_vppn[18:10] == tlb_vppn[5][18:10])  && ((s0_asid == tlb_asid[5])  || tlb_g[5]) && (tlb_ps[5] == 6'd21  || s0_vppn[9:0]==tlb_vppn[ 5][9:0]);
assign match0[6]  = tlb_e[6] & (s0_vppn[18:10] == tlb_vppn[6][18:10])  && ((s0_asid == tlb_asid[6])  || tlb_g[6]) && (tlb_ps[6] == 6'd21  || s0_vppn[9:0]==tlb_vppn[ 6][9:0]);
assign match0[7]  = tlb_e[7] & (s0_vppn[18:10] == tlb_vppn[7][18:10])  && ((s0_asid == tlb_asid[7])  || tlb_g[7]) && (tlb_ps[7] == 6'd21  || s0_vppn[9:0]==tlb_vppn[ 7][9:0]);
assign match0[8]  = tlb_e[8] & (s0_vppn[18:10] == tlb_vppn[8][18:10])  && ((s0_asid == tlb_asid[8])  || tlb_g[8]) && (tlb_ps[8] == 6'd21  || s0_vppn[9:0]==tlb_vppn[ 8][9:0]);
assign match0[9]  = tlb_e[9] & (s0_vppn[18:10] == tlb_vppn[9][18:10])  && ((s0_asid == tlb_asid[9])  || tlb_g[9]) && (tlb_ps[9] == 6'd21  || s0_vppn[9:0]==tlb_vppn[ 9][9:0]);
assign match0[10] = tlb_e[10] & (s0_vppn[18:10] == tlb_vppn[10][18:10]) && ((s0_asid == tlb_asid[10]) || tlb_g[10]) && (tlb_ps[10] == 6'd21  || s0_vppn[9:0]==tlb_vppn[ 10][9:0]);
assign match0[11] = tlb_e[11] & (s0_vppn[18:10] == tlb_vppn[11][18:10]) && ((s0_asid == tlb_asid[11]) || tlb_g[11]) && (tlb_ps[11] == 6'd21  || s0_vppn[9:0]==tlb_vppn[ 11][9:0]);
assign match0[12] = tlb_e[12] & (s0_vppn[18:10] == tlb_vppn[12][18:10]) && ((s0_asid == tlb_asid[12]) || tlb_g[12]) && (tlb_ps[12] == 6'd21  || s0_vppn[9:0]==tlb_vppn[ 12][9:0]);
assign match0[13] = tlb_e[13] & (s0_vppn[18:10] == tlb_vppn[13][18:10]) && ((s0_asid == tlb_asid[13]) || tlb_g[13]) && (tlb_ps[13] == 6'd21  || s0_vppn[9:0]==tlb_vppn[ 13][9:0]);
assign match0[14] = tlb_e[14] & (s0_vppn[18:10] == tlb_vppn[14][18:10]) && ((s0_asid == tlb_asid[14]) || tlb_g[14]) && (tlb_ps[14] == 6'd21  || s0_vppn[9:0]==tlb_vppn[ 14][9:0]);
assign match0[15] = tlb_e[15] & (s0_vppn[18:10] == tlb_vppn[15][18:10]) && ((s0_asid == tlb_asid[15]) || tlb_g[15]) && (tlb_ps[15] == 6'd21  || s0_vppn[9:0]==tlb_vppn[ 15][9:0]);

assign is_match0 = |match0;
assign s0_index = match0[ 0] ? 4'd0  :
                  match0[ 1] ? 4'd1  :
                  match0[ 2] ? 4'd2  :
                  match0[ 3] ? 4'd3  :
                  match0[ 4] ? 4'd4  :
                  match0[ 5] ? 4'd5  :
                  match0[ 6] ? 4'd6  :
                  match0[ 7] ? 4'd7  :
                  match0[ 8] ? 4'd8  :
                  match0[ 9] ? 4'd9  :
                  match0[10] ? 4'd10 :
                  match0[11] ? 4'd11 :
                  match0[12] ? 4'd12 :
                  match0[13] ? 4'd13 :
                  match0[14] ? 4'd14 :
                  match0[15] ? 4'd15 :
                  4'd0;
assign s0_found  = is_match0;
assign s0_ps     = tlb_ps[s0_index];
assign s0_ppn    = s0_ps == 6'd12 && s0_va_bit12 || s0_ps == 6'd21 && s0_vppn[8] ? tlb_ppn1[s0_index] : tlb_ppn0[s0_index];
assign s0_plv    = s0_ps == 6'd12 && s0_va_bit12 || s0_ps == 6'd21 && s0_vppn[8] ? tlb_plv1[s0_index] : tlb_plv0[s0_index];
assign s0_mat    = s0_ps == 6'd12 && s0_va_bit12 || s0_ps == 6'd21 && s0_vppn[8] ? tlb_mat1[s0_index] : tlb_mat0[s0_index];
assign s0_d      = s0_ps == 6'd12 && s0_va_bit12 || s0_ps == 6'd21 && s0_vppn[8] ? tlb_d1[s0_index]   :   tlb_d0[s0_index];
assign s0_v      = s0_ps == 6'd12 && s0_va_bit12 || s0_ps == 6'd21 && s0_vppn[8] ? tlb_v1[s0_index]   :   tlb_v0[s0_index];

wire is_match1;

assign match1[0]  = tlb_e[0] & (s1_vppn[18:9] == tlb_vppn[0][18:9])  && ((s1_asid == tlb_asid[0])  || tlb_g[0]) && (tlb_ps[0] == 6'd21  || s1_vppn[8:0]==tlb_vppn[ 0][8:0]);
assign match1[1]  = tlb_e[1] & (s1_vppn[18:9] == tlb_vppn[1][18:9])  && ((s1_asid == tlb_asid[1])  || tlb_g[1]) && (tlb_ps[1] == 6'd21  || s1_vppn[8:0]==tlb_vppn[ 1][8:0]);
assign match1[2]  = tlb_e[2] & (s1_vppn[18:9] == tlb_vppn[2][18:9])  && ((s1_asid == tlb_asid[2])  || tlb_g[2]) && (tlb_ps[2] == 6'd21  || s1_vppn[8:0]==tlb_vppn[ 2][8:0]);
assign match1[3]  = tlb_e[3] & (s1_vppn[18:9] == tlb_vppn[3][18:9])  && ((s1_asid == tlb_asid[3])  || tlb_g[3]) && (tlb_ps[3] == 6'd21  || s1_vppn[8:0]==tlb_vppn[ 3][8:0]);
assign match1[4]  = tlb_e[4] & (s1_vppn[18:9] == tlb_vppn[4][18:9])  && ((s1_asid == tlb_asid[4])  || tlb_g[4]) && (tlb_ps[4] == 6'd21  || s1_vppn[8:0]==tlb_vppn[ 4][8:0]);
assign match1[5]  = tlb_e[5] & (s1_vppn[18:9] == tlb_vppn[5][18:9])  && ((s1_asid == tlb_asid[5])  || tlb_g[5]) && (tlb_ps[5] == 6'd21  || s1_vppn[8:0]==tlb_vppn[ 5][8:0]);
assign match1[6]  = tlb_e[6] & (s1_vppn[18:9] == tlb_vppn[6][18:9])  && ((s1_asid == tlb_asid[6])  || tlb_g[6]) && (tlb_ps[6] == 6'd21  || s1_vppn[8:0]==tlb_vppn[ 6][8:0]);
assign match1[7]  = tlb_e[7] & (s1_vppn[18:9] == tlb_vppn[7][18:9])  && ((s1_asid == tlb_asid[7])  || tlb_g[7]) && (tlb_ps[7] == 6'd21  || s1_vppn[8:0]==tlb_vppn[ 7][8:0]);
assign match1[8]  = tlb_e[8] & (s1_vppn[18:9] == tlb_vppn[8][18:9])  && ((s1_asid == tlb_asid[8])  || tlb_g[8]) && (tlb_ps[8] == 6'd21  || s1_vppn[8:0]==tlb_vppn[ 8][8:0]);
assign match1[9]  = tlb_e[9] & (s1_vppn[18:9] == tlb_vppn[9][18:9])  && ((s1_asid == tlb_asid[9])  || tlb_g[9]) && (tlb_ps[9] == 6'd21  || s1_vppn[8:0]==tlb_vppn[ 9][8:0]);
assign match1[10] = tlb_e[10] & (s1_vppn[18:9] == tlb_vppn[10][18:9]) && ((s1_asid == tlb_asid[10]) || tlb_g[10]) && (tlb_ps[10] == 6'd21  || s1_vppn[8:0]==tlb_vppn[ 10][8:0]);
assign match1[11] = tlb_e[11] & (s1_vppn[18:9] == tlb_vppn[11][18:9]) && ((s1_asid == tlb_asid[11]) || tlb_g[11]) && (tlb_ps[11] == 6'd21  || s1_vppn[8:0]==tlb_vppn[ 11][8:0]);
assign match1[12] = tlb_e[12] & (s1_vppn[18:9] == tlb_vppn[12][18:9]) && ((s1_asid == tlb_asid[12]) || tlb_g[12]) && (tlb_ps[12] == 6'd21  || s1_vppn[8:0]==tlb_vppn[ 12][8:0]);
assign match1[13] = tlb_e[13] & (s1_vppn[18:9] == tlb_vppn[13][18:9]) && ((s1_asid == tlb_asid[13]) || tlb_g[13]) && (tlb_ps[13] == 6'd21  || s1_vppn[8:0]==tlb_vppn[ 13][8:0]);
assign match1[14] = tlb_e[14] & (s1_vppn[18:9] == tlb_vppn[14][18:9]) && ((s1_asid == tlb_asid[14]) || tlb_g[14]) && (tlb_ps[14] == 6'd21  || s1_vppn[8:0]==tlb_vppn[ 14][8:0]);
assign match1[15] = tlb_e[15] & (s1_vppn[18:9] == tlb_vppn[15][18:9]) && ((s1_asid == tlb_asid[15]) || tlb_g[15]) && (tlb_ps[15] == 6'd21  || s1_vppn[8:0]==tlb_vppn[ 15][8:0]);

assign is_match1 = |match1;
assign s1_index = match1[ 0] ? 4'd0  :
                  match1[ 1] ? 4'd1  :
                  match1[ 2] ? 4'd2  :
                  match1[ 3] ? 4'd3  :
                  match1[ 4] ? 4'd4  :
                  match1[ 5] ? 4'd5  :
                  match1[ 6] ? 4'd6  :
                  match1[ 7] ? 4'd7  :
                  match1[ 8] ? 4'd8  :
                  match1[ 9] ? 4'd9  :
                  match1[10] ? 4'd10 :
                  match1[11] ? 4'd11 :
                  match1[12] ? 4'd12 :
                  match1[13] ? 4'd13 :
                  match1[14] ? 4'd14 :
                  match1[15] ? 4'd15 :
                  4'd0;
assign s1_found  = is_match1;
assign s1_ps     = tlb_ps[s1_index];
assign s1_ppn    = s1_ps == 6'd12 && s1_va_bit12 || s1_ps == 6'd21 && s1_vppn[8] ? tlb_ppn1[s1_index] : tlb_ppn0[s1_index];
assign s1_plv    = s1_ps == 6'd12 && s1_va_bit12 || s1_ps == 6'd21 && s1_vppn[8] ? tlb_plv1[s1_index] : tlb_plv0[s1_index];
assign s1_mat    = s1_ps == 6'd12 && s1_va_bit12 || s1_ps == 6'd21 && s1_vppn[8] ? tlb_mat1[s1_index] : tlb_mat0[s1_index];
assign s1_d      = s1_ps == 6'd12 && s1_va_bit12 || s1_ps == 6'd21 && s1_vppn[8] ? tlb_d1[s1_index]   :   tlb_d0[s1_index];
assign s1_v      = s1_ps == 6'd12 && s1_va_bit12 || s1_ps == 6'd21 && s1_vppn[8] ? tlb_v1[s1_index]   :   tlb_v0[s1_index];


endmodule