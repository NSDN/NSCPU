#include "nscpu.h"

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

/**
 *  CMD
 *      Byte 0                          Byte 1                          Byte 2
 *      7   6   5   4   3   2   1   0   7   6   5   4   3   2   1   0   7   6   5   4   3   2   1   0
 *      CMD[2:0]    SL[1:0] DL[1:0] CL  CMD[7:3]            ST  DT  CL  EXT[7:0]
 *  DAT
 *      Byte 0  Byte 1  Byte 2  Byte 3  Byte 4  Byte 5  TOTAL(MAX)
 *      -       -       -       -       -       -       3 bytes
 *      DR[7:0] -       -       -       -       -       4 bytes
 *      DR[15:0]        -       -       -       -       5 bytes
 *      DR[23:0]                -       -       -       6 bytes
 *      DR[7:0] SR[7:0] -       -       -       -       5 bytes
 *      DR[15:0]        SR[7:0] -       -       -       6 bytes
 *      DR[23:0]                SR[7:0] -       -       7 bytes
 *      DR[7:0] SR[15:0]        -       -       -       6 bytes
 *      DR[15:0]        SR[15:0]        -       -       7 bytes
 *      DR[23:0]                SR[15:0]        -       8 bytes
 *      DR[7:0] SR[23:0]                -       -       7 bytes
 *      DR[15:0]        SR[23:0]                -       8 bytes
 *      DR[23:0]                SR[23:0]                9 bytes
 **/

volatile uint32_t prog_counter = 0;
volatile uint32_t sys_memory[MEM_SIZE] = { 0 };
volatile uint32_t prev_expr = 0;

#include "instrs.h"
static Func func_list[] = {
    { instr_nop },
    { instr_mov },
    { instr_add },
    { instr_sub },
    { instr_int },
    { instr_jmp },
    { instr_jnz },
    { instr_hlt },

    { instr_push },
    { instr_pop },
    { instr_not },
    { instr_and },
    { instr_or },
    { instr_xor },
    { instr_shl },
    { instr_shr },

    { instr_cmp },
    { instr_jg },
    { instr_jl },
    { instr_jz },
    { instr_loop },
    { instr_rst },
    { instr_in },
    { instr_out },
};

int nscpu_execute(Inst* inst) {
    if (inst == NULL)
        return -1;
    if (inst->cmd >= sizeof(func_list))
        return -2;
    return func_list[inst->cmd].f(inst->ext, inst->dst_type, inst->dst, inst->src_type, inst->src);
}

int nscpu_parse(Inst* inst, uint8_t* code, uint32_t offset) {
    if (inst == NULL || code == NULL)
        return -1;
    memset(inst, 0, sizeof(Inst));
    uint8_t* ptr = code + offset;
    inst->cmd = (ptr[0] & CMD_LB) >> 5;
    uint8_t dl, sl;
    dl = (ptr[0] & CMD_DL) >> 1;
    sl = (ptr[0] & CMD_SL) >> 3;
    if ((ptr[0] & CMD_CL) != 0) {
        inst->cmd |= (ptr[1] & CMD_MB);
        inst->dst_type = ((ptr[1] & CMD_DT) != 0) ? ExprADDR : ExprDATA;
        inst->src_type = ((ptr[1] & CMD_ST) != 0) ? ExprADDR : ExprDATA;
        if ((ptr[1] & CMD_CL) != 0) {
            inst->ext = ptr[2];
            ptr += 3;
        } else
            ptr += 3;//2;
    } else 
        ptr += 3;//1;
    switch (dl) {
        case 1:
            inst->dst.d8 = ptr[0];
            ptr += 3;//1;
            break;
        case 2:
            inst->dst.d16 = (uint16_t) ptr[0] | ((uint16_t) ptr[1] << 8);
            ptr += 3;//2;
            break;
        case 3:
            inst->dst.d24 = (uint32_t) ptr[0] | ((uint32_t) ptr[1] << 8) | ((uint32_t) ptr[2] << 16);
            ptr += 3;
            break;
        default:
            break;
    }
    switch (sl) {
        case 1:
            inst->src.d8 = ptr[0];
            ptr += 3;//1;
            break;
        case 2:
            inst->src.d16 = (uint16_t) ptr[0] | ((uint16_t) ptr[1] << 8);
            ptr += 3;//2;
            break;
        case 3:
            inst->src.d24 = (uint32_t) ptr[0] | ((uint32_t) ptr[1] << 8) | ((uint32_t) ptr[2] << 16);
            ptr += 3;
            break;
        default:
            break;
    }
    return ptr - (code + offset);
}

int nscpu_run(uint8_t* code, uint32_t len) {
    prog_counter = 0;
    memset((uint32_t*) (sys_memory + DAT_ADDR), 0, DAT_SIZE);
    len %= CODE_SIZE;

    while (prog_counter < len) {
        Inst inst;
        int inst_size = nscpu_parse(&inst, code, prog_counter);
        //printf("[DBG] %02X %C:%06X %C:%06X LEN: %02X\n", inst.cmd, inst.dst_type ? 'A' : 'I', inst.dst, inst.src_type ? 'A' : 'I', inst.src, inst_size);
        if (inst_size <= 0)
            return -1;

        int res = nscpu_execute(&inst);
        switch (res) {
            case RES_OK:
                prog_counter += inst_size;
                break;
            case RES_RST:
                prog_counter = 0;
                break;
            case RES_ERR:
            case RES_HLT:
                return res;
            default:
                break;
        }
    }

    if (prog_counter > len)
        return -2;
    return 0;
}
