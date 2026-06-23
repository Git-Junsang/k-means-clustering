`include "ervp_global.vh"

module IP_TOP
(
	clk,
	rstnn,

	rpsel,
	rpenable,
	rpaddr,
	rpwrite,
	rpwdata,
	rprdata,
	rpready,
	rpslverr
);

////////////////////////////
/* parameter input output */
////////////////////////////

parameter BW_ADDR = 1;
parameter BW_DATA = 1;

input wire clk, rstnn;
input wire rpsel;
input wire rpenable;
input wire [BW_ADDR-1:0] rpaddr;
input wire rpwrite;
input wire [BW_DATA-1:0] rpwdata;
output reg [BW_DATA-1:0] rprdata;
output wire rpready;
output reg rpslverr;

/////////////
/* signals */
/////////////

genvar i;

wire [8-1:0] addr_offset = rpaddr;
reg is_valid_addr;

reg [32-1:0] var_x, var_y, var_z;
reg we_x, we_y, we_z;

reg request_fadd;
reg request_fsub;
reg request_fmult;
reg request_fdiv;

reg rpready_set;
/* fpu_top 연동 신호 */
wire [32-1:0] fpu_z;       // fpu_top 결과
wire          fpu_done;    // 결과 나온 사이클에 1
wire          any_req  = request_fadd | request_fsub | request_fmult | request_fdiv;
wire          op_addr  = (addr_offset==8'h C) | (addr_offset==8'h 10);
reg           busy;        // FPU 연산 진행 중
reg           op_serviced; // 이번 접근에서 결과를 이미 냈는지 (중복 시작 방지)
reg           fpu_req_fadd, fpu_req_fsub, fpu_req_fmult, fpu_req_fdiv; // 1사이클 시작 펄스

////////////
/* logics */
////////////

always@(*)
begin
	rprdata = 0;
	is_valid_addr = 0;
	we_x = 0;
	we_y = 0;
	we_z = 0;
	request_fadd = 0;
	request_fsub = 0;
	request_fmult = 0;
	request_fdiv = 0;

	if(rpsel==1'b 1)
	begin
		if(rpenable==1'b 1)
		begin
			case(addr_offset)
				8'h 0:
				begin
					is_valid_addr = 1;
					rprdata = var_x;
					we_x = rpwrite;
				end
				8'h 4:
				begin
					is_valid_addr = 1;
					rprdata = var_y;
					we_y = rpwrite;
				end
				8'h 8:
				begin
					is_valid_addr = 1;
					rprdata = var_z;
					we_z = rpwrite;
				end
				8'h C:
				begin
					is_valid_addr = 1;
					if(rpwrite==1'b 1)
						request_fadd = 1;
					else
						request_fsub = 1;
				end
				8'h 10:
				begin
					is_valid_addr = 1;
					if(rpwrite==1'b 1)
						request_fmult = 1;
					else
						request_fdiv = 1;
				end
				default:
					is_valid_addr = 0;			
			endcase
		end
	end
end

always@(posedge clk, negedge rstnn)
begin
	if(rstnn==0) var_x <= 0;
	else if(we_x==1'b 1) var_x <= rpwdata;
end
always@(posedge clk, negedge rstnn)
begin
	if(rstnn==0) var_y <= 0;
	else if(we_y==1'b 1) var_y <= rpwdata;
end

always@(posedge clk, negedge rstnn)
begin
	if(rstnn==0)
		var_z <= 0;
	else if(we_z==1'b 1)
		var_z <= rpwdata;
	else if(fpu_done)            // FPU 연산 끝나면 결과 저장
		var_z <= fpu_z;
end



/* 시작 펄스 / busy 제어 + fpu_top 인스턴스 */
// APB wait 동안 레벨로 유지되는 request 를 1사이클 시작 펄스로 바꾸고,
// 결과 나올 때까지 busy 유지. op_serviced 로 같은 접근에서 재시작 방지.
always@(posedge clk, negedge rstnn)
begin
	if(rstnn==0)
	begin
		busy         <= 0;
		op_serviced  <= 0;
		fpu_req_fadd <= 0; fpu_req_fsub <= 0; fpu_req_fmult <= 0; fpu_req_fdiv <= 0;
	end
	else
	begin
		fpu_req_fadd <= 0; fpu_req_fsub <= 0; fpu_req_fmult <= 0; fpu_req_fdiv <= 0;
		if(!busy)
		begin
			if(any_req && !op_serviced)
			begin
				busy         <= 1;
				fpu_req_fadd <= request_fadd;
				fpu_req_fsub <= request_fsub;
				fpu_req_fmult<= request_fmult;
				fpu_req_fdiv <= request_fdiv;
			end
			else if(!any_req)
				op_serviced <= 0;          // 접근 끝나면 다음 연산 위해 리셋
		end
		else if(fpu_done)
		begin
			busy        <= 0;
			op_serviced <= 1;              // 이번 접근의 결과 냈음
		end
	end
end

fpu_top u_fpu_top
(
	.clk(clk),
	.rstnn(rstnn),
	.var_x(var_x),
	.var_y(var_y),
	.request_fadd(fpu_req_fadd),
	.request_fsub(fpu_req_fsub),
	.request_fmult(fpu_req_fmult),
	.request_fdiv(fpu_req_fdiv),
	.var_z(fpu_z),
	.done(fpu_done)
);



assign rpready = rpready_set;

always@(posedge clk, negedge rstnn)
begin
	if(rstnn == 0) rpready_set <= 1;
	else if(rpsel && op_addr && !op_serviced) rpready_set <= 0; // 연산 중이면 wait
	else                                      rpready_set <= 1; // 그 외에는 ready
end

always@(posedge clk, negedge rstnn)
begin
	if(rstnn==0)
		rpslverr<= 0;
	else if(rpsel==1'b 1)
	begin
		if(rpenable==1'b 0)
			rpslverr <= 0;
		else
			rpslverr <= ~is_valid_addr;
	end
end

endmodule




