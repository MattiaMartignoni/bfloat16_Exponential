package main_pkg;

typedef enum logic
	{
		FPU_RNDMODE_NEAREST		=	'd0,
		FPU_RNDMODE_TRUNCATE	=	'd1
	} rndModeFPU_t;

	typedef enum logic[1:0]
	{
		FPU_IDLE	= 2'd0,
		FPU_ADD		= 2'd1,
		FPU_SUB		= 2'd2,
		FPU_MUL		= 2'd3
	} opcodeFPU_t;
	
endpackage