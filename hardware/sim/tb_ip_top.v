// =====================================================================
// tb_ip_top.v  -  APB-master testbench for IP_TOP (Step 2, local sim)
//
//   Drives the rp* (APB-like) interface exactly as fpu_test.c does:
//     set_x -> set_y -> perform_op -> get_z
//   and checks the result, exercising the rpready wait-state handshake.
//
//   Register map:
//     0x0 W:x        0x4 W:y        0x8 R:z(result)
//     0xC W:fadd / R:fsub          0x10 W:fmult / R:fdiv
//
//   Local run:  ./hardware/sim/run_ip.sh
// =====================================================================
`timescale 1ns/1ps
module tb_ip_top;

    localparam BW = 32;

    reg            clk, rstnn;
    reg            rpsel, rpenable, rpwrite;
    reg  [BW-1:0]  rpaddr, rpwdata;
    wire [BW-1:0]  rprdata;
    wire           rpready, rpslverr;

    integer errors = 0;

    localparam [31:0] X = 32'h41687AE1, Y = 32'h42AFD1EC;
    localparam [31:0] EXP_ADD = 32'h42CCE148, EXP_SUB = 32'hC292C290,
                      EXP_MUL = 32'h449FAAA2, EXP_DIV = 32'h3E293FDC;

    IP_TOP #(.BW_ADDR(BW), .BW_DATA(BW)) uut (
        .clk(clk), .rstnn(rstnn),
        .rpsel(rpsel), .rpenable(rpenable), .rpaddr(rpaddr),
        .rpwrite(rpwrite), .rpwdata(rpwdata), .rprdata(rprdata),
        .rpready(rpready), .rpslverr(rpslverr)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // ---------- APB master transactions (with wait-state polling) -------
    task apb_write(input [BW-1:0] addr, input [BW-1:0] data);
        integer guard;
        begin
            @(negedge clk);  rpsel=1; rpwrite=1; rpaddr=addr; rpwdata=data; rpenable=0; // SETUP
            @(negedge clk);  rpenable=1;                                                // ACCESS
            guard=0;
            @(posedge clk);
            while (rpready!==1'b1 && guard<2000) begin @(posedge clk); guard=guard+1; end
            @(negedge clk);  rpsel=0; rpenable=0; rpwrite=0;
        end
    endtask

    task apb_read(input [BW-1:0] addr, output [BW-1:0] data);
        integer guard;
        begin
            @(negedge clk);  rpsel=1; rpwrite=0; rpaddr=addr; rpenable=0;               // SETUP
            @(negedge clk);  rpenable=1;                                                // ACCESS
            guard=0;
            @(posedge clk);
            while (rpready!==1'b1 && guard<2000) begin @(posedge clk); guard=guard+1; end
            data = rprdata;
            @(negedge clk);  rpsel=0; rpenable=0;
        end
    endtask

    reg [31:0] z, dummy;

    task check(input [127:0] name, input [31:0] got, input [31:0] exp);
        begin
            if (got===exp) $display("  [PASS] %0s : z = 32'h%08X", name, got);
            else begin $display("  [FAIL] %0s : z = 32'h%08X , expected 32'h%08X", name, got, exp); errors=errors+1; end
        end
    endtask

    initial begin
        rstnn=0; rpsel=0; rpenable=0; rpwrite=0; rpaddr=0; rpwdata=0;
        repeat (4) @(posedge clk);
        rstnn=1;
        repeat (2) @(posedge clk);

        $display("=== IP_TOP APB simulation : x=14.53, y=87.91 ===");

        apb_write(32'h0, X);          // set_x
        apb_write(32'h4, Y);          // set_y

        apb_write(32'hC, 32'h0);      // perform_fadd (W 0xC)
        apb_read (32'h8, z);  check("fadd  (x+y)", z, EXP_ADD);

        apb_read (32'hC, dummy);      // perform_fsub (R 0xC)
        apb_read (32'h8, z);  check("fsub  (x-y)", z, EXP_SUB);

        apb_write(32'h10, 32'h0);     // perform_fmult (W 0x10)
        apb_read (32'h8, z);  check("fmult (x*y)", z, EXP_MUL);

        apb_read (32'h10, dummy);     // perform_fdiv (R 0x10)
        apb_read (32'h8, z);  check("fdiv  (x/y)", z, EXP_DIV);

        // also confirm plain register read-back still works
        apb_read (32'h0, z);  check("readback x", z, X);
        apb_read (32'h4, z);  check("readback y", z, Y);

        $display("=== DONE : %0d error(s) ===", errors);
        if (errors==0) $display("RESULT: ALL TESTS PASSED");
        else           $display("RESULT: %0d TEST(S) FAILED", errors);
        $finish;
    end

    initial begin #500000; $display("RESULT: TIMEOUT"); $finish; end

endmodule
