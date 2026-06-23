// tb_fpu_top.v : fpu_top 단독 테스트벤치 (Step 1)
//   x=14.53, y=87.91 로 fadd/fsub/fmult/fdiv 를 시켜보고
//   결과 var_z 를 IEEE-754 기대값과 비교한다.
`timescale 1ns/1ps
module tb_fpu_top;

    reg         clk, rstnn;
    reg  [31:0] var_x, var_y;
    reg         request_fadd, request_fsub, request_fmult, request_fdiv;
    wire [31:0] var_z;

    integer     errors = 0;

    // 입력 (float32)
    localparam [31:0] X = 32'h41687AE1;   // 14.53
    localparam [31:0] Y = 32'h42AFD1EC;   // 87.91

    // 기대값 (float32)
    localparam [31:0] EXP_ADD = 32'h42CCE148;   //  102.44
    localparam [31:0] EXP_SUB = 32'hC292C290;   //  -73.38
    localparam [31:0] EXP_MUL = 32'h449FAAA2;   // 1277.33
    localparam [31:0] EXP_DIV = 32'h3E293FDC;   //    0.165283

    fpu_top uut (
        .clk(clk), .rstnn(rstnn),
        .var_x(var_x), .var_y(var_y),
        .request_fadd(request_fadd), .request_fsub(request_fsub),
        .request_fmult(request_fmult), .request_fdiv(request_fdiv),
        .var_z(var_z)
    );

    // 100 MHz
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // 연산 1회 : request 한 사이클 주고, FSM 이 idle 로 돌아올 때까지 기다림
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

            guard = 0;
            @(posedge clk);                       // S_RUN 진입
            while (uut.state !== 1'b0 && guard < 2000) begin
                @(posedge clk);
                guard = guard + 1;
            end
            @(posedge clk);                       // var_z 안정화

            if (var_z === expected)
                $display("  [PASS] %0s : var_z = 32'h%08X (%0d cycles)", name, var_z, guard);
            else begin
                $display("  [FAIL] %0s : var_z = 32'h%08X , expected 32'h%08X", name, var_z, expected);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
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
        repeat (100) @(posedge clk);   // 마지막 fdiv 결과(0.1653)가 파형에 남도록 잠깐 더 진행
        $finish;
    end

    // 안전용 타임아웃
    initial begin
        #200000;
        $display("RESULT: TIMEOUT");
        $finish;
    end

endmodule
