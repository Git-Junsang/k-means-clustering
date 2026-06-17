#include "platform_info.h"
#include "ervp_printf.h"
#include "ervp_reg_util.h"

#define OFFSET_X 0x0
#define OFFSET_Y 0x4
#define OFFSET_Z 0x8
#define OFFSET_FADD 0xC
#define OFFSET_FSUB 0xC
#define OFFSET_FDIV 0x10
#define OFFSET_FMULT 0x10

#define REG32_fl(add) *((volatile float *)(add))

static inline unsigned int get_test1_addr(unsigned int offset)
{
	return (I_TEST1_SLAVE_BASEADDR + offset);
}

void set_x(float value)
{
	REG32_fl(get_test1_addr(OFFSET_X)) = value;
}

void set_y(float value)
{
	REG32_fl(get_test1_addr(OFFSET_Y)) = value;
}

void set_z(float value)
{
	REG32_fl(get_test1_addr(OFFSET_Z)) = value;
}

float get_x()
{
	return REG32_fl(get_test1_addr(OFFSET_X));
}

float get_y()
{
	return REG32_fl(get_test1_addr(OFFSET_Y));
}

float get_z()
{
	return REG32_fl(get_test1_addr(OFFSET_Z));
}

void perform_fadd()
{
	REG32(get_test1_addr(OFFSET_FADD)) = 0;
}

void perform_fsub()
{
	int temp;
	temp = REG32(get_test1_addr(OFFSET_FSUB));
}

void perform_fmult()
{
	REG32(get_test1_addr(OFFSET_FMULT)) = 0;
}

void perform_fdiv()
{
	int temp;
	temp = REG32(get_test1_addr(OFFSET_FDIV));
}


int main()
{
	set_x(14.53);
	printf("\nx : %.2f", get_x());
	set_y(87.91);
	printf("\ny : %.2f", get_y());
	set_z(670.72);
	printf("\nz : %.2f", get_z());
	perform_fadd();
	printf("\nfadd : %.2f", get_z());
	perform_fsub();
	printf("\nfsub : %.2f", get_z());
	perform_fmult();
	printf("\nfmult : %.2f", get_z());
	perform_fdiv();
	printf("\nfdiv : %.2f", get_z());
	
	return 0;
}
