// fp32_fma.sv — DC K-2015 compatible (no always_comb, no inline declarations)
module fp32_fma (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [31:0] c,
    input  wire [2:0]  frm,
    output reg  [31:0] result,
    output reg  [4:0]  fflags
);
    wire sa = a[31]; wire [7:0] ea = a[30:23]; wire [22:0] fa = a[22:0];
    wire sb = b[31]; wire [7:0] eb = b[30:23]; wire [22:0] fb = b[22:0];
    wire sc = c[31]; wire [7:0] ec = c[30:23]; wire [22:0] fc = c[22:0];

    wire [23:0] ma = {|ea, fa};
    wire [23:0] mb = {|eb, fb};
    wire [23:0] mc = {|ec, fc};

    wire a_nan=(ea==8'hFF)&(fa!=0); wire b_nan=(eb==8'hFF)&(fb!=0); wire c_nan=(ec==8'hFF)&(fc!=0);
    wire a_inf=(ea==8'hFF)&(fa==0); wire b_inf=(eb==8'hFF)&(fb==0); wire c_inf=(ec==8'hFF)&(fc==0);
    wire a_zero=(ea==8'h00); wire b_zero=(eb==8'h00); wire c_zero=(ec==8'h00);
    wire any_nan=a_nan|b_nan|c_nan; wire sp=sa^sb;
    wire prod_inf_nan=(a_inf&b_zero)|(b_inf&a_zero);

    wire [47:0] prod_mant = ma * mb;
    wire [9:0]  ep_raw = ({2'b00,ea}+{2'b00,eb})-10'd127;
    wire [47:0] p48 = prod_mant[47] ? prod_mant : (prod_mant<<1);
    wire [9:0]  ep  = prod_mant[47] ? (ep_raw+10'd1) : ep_raw;

    wire signed [10:0] diff = $signed({1'b0,ep}) - $signed({2'b00,ec});
    localparam ACC=74;

    reg [ACC-1:0] p_acc, c_acc;
    reg [9:0] result_exp; reg result_sign;
    always @(*) begin
        p_acc={ACC{1'b0}}; c_acc={ACC{1'b0}}; result_exp=ep; result_sign=sp;
        if(diff>=0 && diff<ACC)      begin p_acc={p48,{(ACC-48){1'b0}}}; c_acc=({mc,{(ACC-24){1'b0}}}>>diff); result_exp=ep; end
        else if(diff<0 && -diff<ACC) begin c_acc={mc,{(ACC-24){1'b0}}}; p_acc=({p48,{(ACC-48){1'b0}}}>>(-diff)); result_exp={2'b00,ec}; end
        else if(diff>=ACC)           begin p_acc={p48,{(ACC-48){1'b0}}}; result_exp=ep; end
        else                         begin c_acc={mc,{(ACC-24){1'b0}}}; result_exp={2'b00,ec}; end
    end

    wire sub=sp^sc;
    reg [ACC:0] sum_full;
    reg result_sign2;
    always @(*) begin
        if(!sub)          begin sum_full={1'b0,p_acc}+{1'b0,c_acc}; result_sign2=sp; end
        else if(p_acc>=c_acc) begin sum_full={1'b0,p_acc}-{1'b0,c_acc}; result_sign2=sp; end
        else              begin sum_full={1'b0,c_acc}-{1'b0,p_acc}; result_sign2=sc; end
    end

    reg [6:0] lzc; integer k;
    always @(*) begin
        lzc=7'd74;
        for(k=ACC;k>=0;k=k-1) if(sum_full[k]) lzc = ACC - k;
    end

    wire result_sign_f = result_sign2;
    wire [ACC:0] norm_mant=sum_full<<lzc;
    wire [9:0]   norm_exp=result_exp-{3'b0,lzc}+10'd26;
    wire [22:0]  mant_out=norm_mant[ACC-1-:23];
    wire guard=norm_mant[ACC-24]; wire sticky=|norm_mant[ACC-25:0];
    reg round_up;
    always @(*) begin
        case(frm)
            3'b000: round_up=guard&(sticky|mant_out[0]);
            3'b001: round_up=1'b0;
            3'b010: round_up=result_sign&(guard|sticky);
            3'b011: round_up=~result_sign&(guard|sticky);
            3'b100: round_up=guard;
            default:round_up=guard&(sticky|mant_out[0]);
        endcase
    end

    wire [23:0] mant_r={1'b0,mant_out}+{23'b0,round_up};
    wire [9:0]  exp_r=norm_exp+{9'b0,mant_r[23]};
    wire [31:0] norm_res={result_sign_f,exp_r[7:0],mant_r[22:0]};

    always @(*) begin
        fflags=5'b0;
        if(any_nan|prod_inf_nan) begin result=32'h7FC00000; fflags[4]=1'b1; end
        else if(a_inf|b_inf) begin
            if(c_inf&&(sc!=sp)) begin result=32'h7FC00000; fflags[4]=1'b1; end
            else result={sp,8'hFF,23'b0};
        end else if(c_inf)       result={sc,8'hFF,23'b0};
        else if(a_zero|b_zero)   result=c_zero?{sp&sc,31'b0}:c;
        else if(|sum_full==1'b0) result=32'h0;
        else if(norm_exp>=10'd255) begin result={result_sign_f,8'hFF,23'b0}; fflags[2]=1'b1; fflags[0]=1'b1; end
        else if(norm_exp==10'b0||norm_exp[9]) begin result={result_sign_f,31'b0}; fflags[1]=1'b1; end
        else begin result=norm_res; fflags[0]=(guard|sticky); end
    end
endmodule
