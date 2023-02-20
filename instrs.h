#ifndef __INSTRS_H_
#define __INSTRS_H_


#include "nscpu.h"
#include <stdint.h>

NSCPU_FUNC_DEF(instr_nop);
NSCPU_FUNC_DEF(instr_mov);
NSCPU_FUNC_DEF(instr_add);
NSCPU_FUNC_DEF(instr_sub);
NSCPU_FUNC_DEF(instr_int);
NSCPU_FUNC_DEF(instr_jmp);
NSCPU_FUNC_DEF(instr_jnz);
NSCPU_FUNC_DEF(instr_hlt);

NSCPU_FUNC_DEF(instr_push);
NSCPU_FUNC_DEF(instr_pop);
NSCPU_FUNC_DEF(instr_not);
NSCPU_FUNC_DEF(instr_and);
NSCPU_FUNC_DEF(instr_or);
NSCPU_FUNC_DEF(instr_xor);
NSCPU_FUNC_DEF(instr_shl);
NSCPU_FUNC_DEF(instr_shr);

NSCPU_FUNC_DEF(instr_cmp);
NSCPU_FUNC_DEF(instr_jg);
NSCPU_FUNC_DEF(instr_jl);
NSCPU_FUNC_DEF(instr_jz);
NSCPU_FUNC_DEF(instr_loop);
NSCPU_FUNC_DEF(instr_rst);
NSCPU_FUNC_DEF(instr_in);
NSCPU_FUNC_DEF(instr_out);


#endif
