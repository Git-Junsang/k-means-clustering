// fpu_top.v : FPU 사칙연산 제어 top (Step 1)
//  - adder / multiplier / divider 각 1개만 인스턴스 (중복 X)
//  - 뺄셈은 b 부호비트만 반전해서 덧셈기로 처리 (x - y = x + (-y))
//  - FSM으로 선택된 모듈의 stb/ack handshake를 처리하고 결과를 var_z에 저장
module fpu_top
(
    input  wire        clk,
    input  wire        rstnn,

    input  wire [31:0] var_x,
    input  wire [31:0] var_y,

    input  wire        request_fadd,
    input  wire        request_fsub,
    input  wire        request_fmult,
    input  wire        request_fdiv,

    output reg  [31:0] var_z,
    output reg         done       // 결과가 새로 나온 그 사이클에만 1
);

    localparam OP_ADD = 2'd0,   // 덧셈/뺄셈 공용
               OP_MUL = 2'd1,
               OP_DIV = 2'd2;

    localparam S_IDLE = 1'b0,
               S_RUN  = 1'b1;

    reg        state;
    reg [1:0]  op_sel;
    reg [31:0] oper_a, oper_b;   // 세 모듈에 공통으로 넣는 입력
    reg        a_done, b_done;   // 입력 a/b 가 받아들여졌는지

    wire [31:0] in_a = oper_a;
    wire [31:0] in_b = oper_b;

    // 선택된 모듈에만 stb/ack 를 준다
    reg  add_a_stb, add_b_stb, add_z_ack;
    reg  mul_a_stb, mul_b_stb, mul_z_ack;
    reg  div_a_stb, div_b_stb, div_z_ack;

    wire add_a_ack, add_b_ack, add_z_stb;  wire [31:0] add_z;
    wire mul_a_ack, mul_b_ack, mul_z_stb;  wire [31:0] mul_z;
    wire div_a_ack, div_b_ack, div_z_stb;  wire [31:0] div_z;

    // 지금 선택된 모듈의 ack/결과를 골라온다
    reg        sel_a_ack, sel_b_ack, sel_z_stb;
    reg [31:0] sel_z;
    always @(*) begin
        case (op_sel)
            OP_MUL : begin sel_a_ack=mul_a_ack; sel_b_ack=mul_b_ack; sel_z_stb=mul_z_stb; sel_z=mul_z; end
            OP_DIV : begin sel_a_ack=div_a_ack; sel_b_ack=div_b_ack; sel_z_stb=div_z_stb; sel_z=div_z; end
            default: begin sel_a_ack=add_a_ack; sel_b_ack=add_b_ack; sel_z_stb=add_z_stb; sel_z=add_z; end
        endcase
    end

    // 실행 중일 때만 선택된 모듈에 stb 를 올린다
    always @(*) begin
        add_a_stb=1'b0; add_b_stb=1'b0; add_z_ack=1'b0;
        mul_a_stb=1'b0; mul_b_stb=1'b0; mul_z_ack=1'b0;
        div_a_stb=1'b0; div_b_stb=1'b0; div_z_ack=1'b0;
        if (state==S_RUN) begin
            case (op_sel)
                OP_MUL : begin mul_a_stb=~a_done; mul_b_stb=~b_done; mul_z_ack=1'b1; end
                OP_DIV : begin div_a_stb=~a_done; div_b_stb=~b_done; div_z_ack=1'b1; end
                default: begin add_a_stb=~a_done; add_b_stb=~b_done; add_z_ack=1'b1; end
            endcase
        end
    end

    // 제어 FSM
    always @(posedge clk, negedge rstnn) begin
        if (!rstnn) begin
            state  <= S_IDLE;
            op_sel <= OP_ADD;
            oper_a <= 32'd0;
            oper_b <= 32'd0;
            a_done <= 1'b0;
            b_done <= 1'b0;
            var_z  <= 32'd0;
            done   <= 1'b0;
        end
        else begin
            done <= 1'b0;                     // 기본은 0, 결과 나온 사이클에만 1
            case (state)
                S_IDLE: begin
                    a_done <= 1'b0;
                    b_done <= 1'b0;
                    if (request_fadd) begin
                        op_sel <= OP_ADD; oper_a <= var_x; oper_b <= var_y;                      state <= S_RUN;
                    end
                    else if (request_fsub) begin
                        // 뺄셈 : y 부호비트만 뒤집어서 덧셈기로
                        op_sel <= OP_ADD; oper_a <= var_x; oper_b <= {~var_y[31], var_y[30:0]};  state <= S_RUN;
                    end
                    else if (request_fmult) begin
                        op_sel <= OP_MUL; oper_a <= var_x; oper_b <= var_y;                      state <= S_RUN;
                    end
                    else if (request_fdiv) begin
                        op_sel <= OP_DIV; oper_a <= var_x; oper_b <= var_y;                      state <= S_RUN;
                    end
                end

                S_RUN: begin
                    if (sel_a_ack) a_done <= 1'b1;   // 입력 a 받아들여짐
                    if (sel_b_ack) b_done <= 1'b1;   // 입력 b 받아들여짐
                    if (sel_z_stb) begin             // 결과 나옴
                        var_z <= sel_z;
                        done  <= 1'b1;
                        state <= S_IDLE;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

    // 모듈 인스턴스 (각 1개)
    fpu_adder u_adder (
        .clk(clk), .rstnn(rstnn),
        .input_a(in_a), .input_a_stb(add_a_stb), .input_a_ack(add_a_ack),
        .input_b(in_b), .input_b_stb(add_b_stb), .input_b_ack(add_b_ack),
        .output_z(add_z), .output_z_stb(add_z_stb), .output_z_ack(add_z_ack)
    );

    fpu_multiplier u_mult (
        .clk(clk), .rstnn(rstnn),
        .input_a(in_a), .input_a_stb(mul_a_stb), .input_a_ack(mul_a_ack),
        .input_b(in_b), .input_b_stb(mul_b_stb), .input_b_ack(mul_b_ack),
        .output_z(mul_z), .output_z_stb(mul_z_stb), .output_z_ack(mul_z_ack)
    );

    fpu_divider u_div (
        .clk(clk), .rstnn(rstnn),
        .input_a(in_a), .input_a_stb(div_a_stb), .input_a_ack(div_a_ack),
        .input_b(in_b), .input_b_stb(div_b_stb), .input_b_ack(div_b_ack),
        .output_z(div_z), .output_z_stb(div_z_stb), .output_z_ack(div_z_ack)
    );

endmodule
