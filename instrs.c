#include "instrs.h"

#include <stdio.h>
#include <string.h>

/**
 * ---- Base Instruction ----
 * 0x00 nop
 * 0x01 mov dst, src
 * 0x02 add dst, src
 * 0x03 sub dst, src
 * 0x04 int vec
 * 0x05 jmp addr
 * 0x06 jnz addr
 * 0x07 hlt
 * ---- Core Instruction ----
 * 0x08 push dst
 * 0x09 pop dst
 * 0x0A not dst
 * 0x0B and dst, src
 * 0x0C or dst, src
 * 0x0D xor dst, src
 * 0x0E shl dst, src
 * 0x0F shr dst, src
 * --------------------------
 * 0x10 cmp dst, src
 * 0x11 jg addr
 * 0x12 jl addr
 * 0x13 jz addr
 * 0x14 loop ext, dst, addr
 * 0x15 rst
 * 0x16 in dst, addr
 * 0x17 out addr, data
 **/

extern uint32_t prog_counter;
extern uint32_t sys_memory[];
extern uint32_t prev_expr;

static uint32_t stack[32] = { 0 };
static uint8_t stack_ptr = 0;

NSCPU_FUNC_DEF(instr_nop) {
    return RES_OK;
}
NSCPU_FUNC_DEF(instr_mov) {
    if (dst_type == ExprDATA)
        return RES_ERR;
    if (src_type == ExprADDR)
        sys_memory[dst.d24] = sys_memory[src.d24];
    else
        sys_memory[dst.d24] = src.d24;

    prev_expr = sys_memory[dst.d24];
    return RES_OK;
}
NSCPU_FUNC_DEF(instr_add) {
    if (dst_type == ExprDATA)
        return RES_ERR;
    if (src_type == ExprADDR)
        sys_memory[dst.d24] += sys_memory[src.d24];
    else
        sys_memory[dst.d24] += src.d24;

    prev_expr = sys_memory[dst.d24];
    return RES_OK;
}
NSCPU_FUNC_DEF(instr_sub) {
    if (dst_type == ExprDATA)
        return RES_ERR;
    if (src_type == ExprADDR)
        sys_memory[dst.d24] -= sys_memory[src.d24];
    else
        sys_memory[dst.d24] -= src.d24;

    prev_expr = sys_memory[dst.d24];
    return RES_OK;
}
NSCPU_FUNC_DEF(instr_int) {
    if (dst_type == ExprADDR)
        printf("[INT] %06X\n", sys_memory[dst.d24]);
    else
        printf("[INT] %06X\n", dst.d24);

    prev_expr = dst_type == ExprADDR ? sys_memory[dst.d24] : dst.d24;
    return RES_OK;
}
NSCPU_FUNC_DEF(instr_jmp) {
    if (dst_type == ExprADDR)
        prog_counter = sys_memory[dst.d24] * 3;
    else
        prog_counter = dst.d24 * 3;

    prev_expr = prog_counter;
    return RES_JMP;
}
NSCPU_FUNC_DEF(instr_jnz) {
    if (prev_expr != 0) {
        if (dst_type == ExprADDR)
            prog_counter = sys_memory[dst.d24] * 3;
        else
            prog_counter = dst.d24 * 3;
        prev_expr = prog_counter;
        return RES_JMP;
    }
    return RES_OK;
}
NSCPU_FUNC_DEF(instr_hlt) {
    return RES_HLT;
}

NSCPU_FUNC_DEF(instr_push) {
    if (stack_ptr >= sizeof(stack))
        return RES_ERR;
    if (dst_type == ExprADDR)
        stack[stack_ptr] = sys_memory[dst.d24];
    else
        stack[stack_ptr] = dst.d24;
    prev_expr = stack[stack_ptr];
    stack_ptr += 1;
    return RES_OK;
}
NSCPU_FUNC_DEF(instr_pop) {
    if (stack_ptr == 0)
        return RES_ERR;
    if (dst_type == ExprADDR) {
        sys_memory[dst.d24] = stack[stack_ptr];
        prev_expr = stack[stack_ptr];
    } else
        return RES_ERR;
    stack_ptr -= 1;
    return RES_OK;
}
NSCPU_FUNC_DEF(instr_not) {
    if (dst_type == ExprDATA)
        return RES_ERR;
    sys_memory[dst.d24] = ~sys_memory[dst.d24];
    prev_expr = sys_memory[dst.d24];
    return RES_OK;
}
NSCPU_FUNC_DEF(instr_and) {
    if (dst_type == ExprDATA)
        return RES_ERR;
    if (src_type == ExprADDR)
        sys_memory[dst.d24] &= sys_memory[src.d24];
    else
        sys_memory[dst.d24] &= src.d24;
    prev_expr = sys_memory[dst.d24];
    return RES_OK;
}
NSCPU_FUNC_DEF(instr_or) {
    if (dst_type == ExprDATA)
        return RES_ERR;
    if (src_type == ExprADDR)
        sys_memory[dst.d24] |= sys_memory[src.d24];
    else
        sys_memory[dst.d24] |= src.d24;
    prev_expr = sys_memory[dst.d24];
    return RES_OK;
}
NSCPU_FUNC_DEF(instr_xor) {
    if (dst_type == ExprDATA)
        return RES_ERR;
    if (src_type == ExprADDR)
        sys_memory[dst.d24] ^= sys_memory[src.d24];
    else
        sys_memory[dst.d24] ^= src.d24;
    prev_expr = sys_memory[dst.d24];
    return RES_OK;
}
NSCPU_FUNC_DEF(instr_shl) {
    if (dst_type == ExprDATA)
        return RES_ERR;
    if (src_type == ExprADDR)
        sys_memory[dst.d24] <<= (sys_memory[src.d24] & 0x1F);
    else
        sys_memory[dst.d24] <<= (src.d24 & 0x1F);
    prev_expr = sys_memory[dst.d24];
    return RES_OK;
}
NSCPU_FUNC_DEF(instr_shr) {
    if (dst_type == ExprDATA)
        return RES_ERR;
    if (src_type == ExprADDR)
        sys_memory[dst.d24] >>= (sys_memory[src.d24] & 0x1F);
    else
        sys_memory[dst.d24] >>= (src.d24 & 0x1F);
    prev_expr = sys_memory[dst.d24];
    return RES_OK;
}

NSCPU_FUNC_DEF(instr_cmp) {
    uint32_t d, s;
    if (dst_type == ExprADDR)
        d = sys_memory[dst.d24];
    else
        d = dst.d24;
    if (src_type == ExprADDR)
        s = sys_memory[src.d24];
    else
        s = src.d24;
    prev_expr = d - s;
    return RES_OK;
}
NSCPU_FUNC_DEF(instr_jg) {
    if (prev_expr > 0) {
        if (dst_type == ExprADDR)
            prog_counter = sys_memory[dst.d24] * 3;
        else
            prog_counter = dst.d24 * 3;
        prev_expr = prog_counter;
        return RES_JMP;
    }
    return RES_OK;
}
NSCPU_FUNC_DEF(instr_jl) {
    if (prev_expr < 0) {
        if (dst_type == ExprADDR)
            prog_counter = sys_memory[dst.d24] * 3;
        else
            prog_counter = dst.d24 * 3;
        prev_expr = prog_counter;
        return RES_JMP;
    }
    return RES_OK;
}
NSCPU_FUNC_DEF(instr_jz) {
    if (prev_expr == 0) {
        if (dst_type == ExprADDR)
            prog_counter = sys_memory[dst.d24] * 3;
        else
            prog_counter = dst.d24 * 3;
        prev_expr = prog_counter;
        return RES_JMP;
    }
    return RES_OK;
}
NSCPU_FUNC_DEF(instr_loop) {
    if (dst_type == ExprDATA)
        return RES_ERR;
    if (ext == 0) {
        if (sys_memory[dst.d24] != 0) {
            if (src_type == ExprADDR)
                prog_counter = sys_memory[src.d24];
            else
                prog_counter = src.d24;
            sys_memory[dst.d24] -= 3;
            if (sys_memory[dst.d24] == 0xFFFFFFFF)
                sys_memory[dst.d24] = 0xFFFFFF;

            return RES_JMP;
        }
    } else {
        if (sys_memory[dst.d24] < ext) {
            if (src_type == ExprADDR)
                prog_counter = sys_memory[src.d24];
            else
                prog_counter = src.d24;
            sys_memory[dst.d24] += 3;
            if (sys_memory[dst.d24] == 0xFFFFFF)
                sys_memory[dst.d24] = 0;

            return RES_JMP;
        }
    }
    return RES_OK;
}
NSCPU_FUNC_DEF(instr_rst) {
    return RES_RST;
}
NSCPU_FUNC_DEF(instr_in) {
    if (dst_type == ExprDATA)
        return RES_ERR;
    printf("[IN] %06X <- IO\n", dst.d24);
    prev_expr = dst.d24;
    return RES_OK;
}
NSCPU_FUNC_DEF(instr_out) {
    uint32_t dat;
    if (dst_type == ExprADDR)
        dat = sys_memory[dst.d24];
    else
        dat = dst.d24;
    printf("[OUT] IO <- %06X\n", dat);
    prev_expr = dst_type == ExprADDR ? sys_memory[dst.d24] : dst.d24;
    return RES_OK;
}
