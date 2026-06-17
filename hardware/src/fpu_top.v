// =====================================================================
// fpu_top.v  -  IEEE-754 single precision arithmetic top (add/sub/mul/div)
// K-means FPU IP project, Step 1
//
//  - Instantiates ONE each of fpu_adder / fpu_multiplier / fpu_divider
//    (no duplicate instances).
//  - Subtraction (fsub) is implemented here by feeding the adder with the
//    sign-inverted operand b  (x - y == x + (-y)); the testbench never
//    supplies a negative number for subtraction.
//  - A small FSM drives the stb/ack handshake of the selected module and
//    latches the result into var_z.
//
//  Ports : 8 inputs / 1 output (per project spec)
// =====================================================================
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

    output reg  [31:0] var_z
);

    // ------------------------------------------------------------------
    // local parameters
    // ------------------------------------------------------------------
    localparam OP_ADD = 2'd0,   // adder is shared by fadd and fsub
               OP_MUL = 2'd1,
               OP_DIV = 2'd2;

    localparam S_IDLE = 1'b0,
               S_RUN  = 1'b1;

    // ------------------------------------------------------------------
    // state / datapath registers
    // ------------------------------------------------------------------
    reg        state;
    reg [1:0]  op_sel;
    reg [31:0] oper_a, oper_b;   // latched operands fed to all modules
    reg        a_done, b_done;   // input handshake completion flags

    // ------------------------------------------------------------------
    // module I/O nets
    // ------------------------------------------------------------------
    wire [31:0] in_a = oper_a;
    wire [31:0] in_b = oper_b;

    // strobe / ack to each module (only the selected one is driven active)
    reg  add_a_stb, add_b_stb, add_z_ack;
    reg  mul_a_stb, mul_b_stb, mul_z_ack;
    reg  div_a_stb, div_b_stb, div_z_ack;

    wire add_a_ack, add_b_ack, add_z_stb;  wire [31:0] add_z;
    wire mul_a_ack, mul_b_ack, mul_z_stb;  wire [31:0] mul_z;
    wire div_a_ack, div_b_ack, div_z_stb;  wire [31:0] div_z;

    // ------------------------------------------------------------------
    // mux : selected module's handshake/result
    // ------------------------------------------------------------------
    reg        sel_a_ack, sel_b_ack, sel_z_stb;
    reg [31:0] sel_z;
    always @(*) begin
        case (op_sel)
            OP_MUL : begin sel_a_ack=mul_a_ack; sel_b_ack=mul_b_ack; sel_z_stb=mul_z_stb; sel_z=mul_z; end
            OP_DIV : begin sel_a_ack=div_a_ack; sel_b_ack=div_b_ack; sel_z_stb=div_z_stb; sel_z=div_z; end
            default: begin sel_a_ack=add_a_ack; sel_b_ack=add_b_ack; sel_z_stb=add_z_stb; sel_z=add_z; end
        endcase
    end

    // ------------------------------------------------------------------
    // strobe generation : drive only the selected module while running
    // ------------------------------------------------------------------
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

    // ------------------------------------------------------------------
    // control FSM
    // ------------------------------------------------------------------
    always @(posedge clk, negedge rstnn) begin
        if (!rstnn) begin
            state  <= S_IDLE;
            op_sel <= OP_ADD;
            oper_a <= 32'd0;
            oper_b <= 32'd0;
            a_done <= 1'b0;
            b_done <= 1'b0;
            var_z  <= 32'd0;
        end
        else begin
            case (state)
                S_IDLE: begin
                    a_done <= 1'b0;
                    b_done <= 1'b0;
                    if (request_fadd) begin
                        op_sel <= OP_ADD; oper_a <= var_x; oper_b <= var_y;                      state <= S_RUN;
                    end
                    else if (request_fsub) begin
                        // x - y = x + (-y) : invert sign bit of y
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
                    if (sel_a_ack) a_done <= 1'b1;   // input a accepted
                    if (sel_b_ack) b_done <= 1'b1;   // input b accepted
                    if (sel_z_stb) begin             // result ready
                        var_z <= sel_z;
                        state <= S_IDLE;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

    // ------------------------------------------------------------------
    // module instances (one each)
    // ------------------------------------------------------------------
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
