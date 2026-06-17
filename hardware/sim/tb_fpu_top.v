// =====================================================================
// tb_fpu_top.v  -  standalone testbench for fpu_top (Step 1, RTL sim)
//
//   Verifies fadd / fsub / fmult / fdiv with x = 14.53, y = 87.91
//   (same operands as fpu_test.c).  Compares var_z against the expected
//   IEEE-754 single-precision bit patterns.
//
//   Local run (iverilog):
//     iverilog -o /tmp/fpu_sim hardware/src/fpu_adder.v \
//        hardware/src/fpu_multiplier.v hardware/src/fpu_divider.v \
//        hardware/src/fpu_top.v hardware/sim/tb_fpu_top.v
//     vvp /tmp/fpu_sim
// =====================================================================
`timescale 1ns/1ps
module tb_fpu_top;

    reg         clk, rstnn;
    reg  [31:0] var_x, var_y;
    reg         request_fadd, request_fsub, request_fmult, request_fdiv;
    wire [31:0] var_z;

    integer     errors = 0;

    // operands (IEEE-754 float32)
    localparam [31:0] X = 32'h41687AE1;   // 14.53
    localparam [31:0] Y = 32'h42AFD1EC;   // 87.91

    // expected results (round-to-nearest, float32)
    localparam [31:0] EXP_ADD = 32'h42CCE148;   //  102.44
    localparam [31:0] EXP_SUB = 32'hC292C290;   //  -73.38
    localparam [31:0] EXP_MUL = 32'h449FAAA2;   // 1277.3323
    localparam [31:0] EXP_DIV = 32'h3E293FDC;   //   0.165283

    fpu_top uut (
        .clk(clk), .rstnn(rstnn),
        .var_x(var_x), .var_y(var_y),
        .request_fadd(request_fadd), .request_fsub(request_fsub),
        .request_fmult(request_fmult), .request_fdiv(request_fdiv),
        .var_z(var_z)
    );

    // 100 MHz clock
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // ----- one operation : pulse request, wait for FSM to return idle ---
    task do_op;
        input [3:0]  sel;        // {fdiv,fmult,fsub,fadd}
        input [31:0] expected;
        input [127:0] name;
        integer guard;
        begin
            @(negedge clk);
            {request_fdiv, request_fmult, request_fsub, request_fadd} = sel;
            @(negedge clk);
            {request_fdiv, request_fmult, request_fsub, request_fadd} = 4'b0000;

            // wait until controller finishes (back to idle), with timeout
            guard = 0;
            @(posedge clk);                       // enter S_RUN
            while (uut.state !== 1'b0 && guard < 2000) begin
                @(posedge clk);
                guard = guard + 1;
            end
            @(posedge clk);                       // let var_z settle

            if (var_z === expected)
                $display("  [PASS] %0s : var_z = 32'h%08X (%0d cycles)", name, var_z, guard);
            else begin
                $display("  [FAIL] %0s : var_z = 32'h%08X , expected 32'h%08X", name, var_z, expected);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        // reset
        rstnn = 1'b0;
        var_x = X; var_y = Y;
        {request_fdiv, request_fmult, request_fsub, request_fadd} = 4'b0000;
        repeat (4) @(posedge clk);
        rstnn = 1'b1;
        repeat (2) @(posedge clk);

        $display("=== fpu_top RTL simulation : x=32'h%08X (14.53), y=32'h%08X (87.91) ===", X, Y);

        do_op(4'b0001, EXP_ADD, "fadd  (x+y)");
        do_op(4'b0010, EXP_SUB, "fsub  (x-y)");
        do_op(4'b0100, EXP_MUL, "fmult (x*y)");
        do_op(4'b1000, EXP_DIV, "fdiv  (x/y)");

        $display("=== DONE : %0d error(s) ===", errors);
        if (errors == 0) $display("RESULT: ALL TESTS PASSED");
        else             $display("RESULT: %0d TEST(S) FAILED", errors);
        $finish;
    end

    // global safety timeout
    initial begin
        #200000;
        $display("RESULT: TIMEOUT");
        $finish;
    end

endmodule
