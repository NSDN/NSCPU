#ifndef __NSCPU_H_
#define __NSCPU_H_


#include <stdint.h>

#define CMD_SL  0x18
#define CMD_DL  0x06
#define CMD_CL  0x01
#define CMD_LB  0xE0
#define CMD_MB  0xF8
#define CMD_ST  0x04
#define CMD_DT  0x02

#define RES_OK  0
#define RES_ERR 1
#define RES_HLT 2
#define RES_RST 3
#define RES_JMP 4

#define MEM_SIZE    0x100
#define CODE_ADDR   0x000
#define CODE_SIZE   0x080
#define DAT_ADDR    CODE_SIZE
#define DAT_SIZE   (MEM_SIZE - CODE_SIZE)

typedef enum {
    ExprDATA = 0,
    ExprADDR = 1
} ExprType;

typedef union {
    uint8_t d8;
    uint16_t d16;
    uint32_t d24;
} Expr;

typedef struct {
    uint8_t cmd;
    uint8_t ext;
    ExprType dst_type;
    ExprType src_type;
    Expr dst;
    Expr src;
} Inst;

#define NSCPU_FUNC_DEF(name) int name(uint8_t ext, ExprType dst_type, Expr dst, ExprType src_type, Expr src)

typedef struct {
    int (*f)(uint8_t ext, ExprType dst_type, Expr dst, ExprType src_type, Expr src);
} Func;

int nscpu_execute(Inst* inst);
int nscpu_parse(Inst* inst, uint8_t* code, uint32_t offset);
int nscpu_run(uint8_t* code, uint32_t len);


#endif
