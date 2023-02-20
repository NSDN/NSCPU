#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "nscpu.h"

const static char help_str[2048] = "TEXT";

extern uint32_t sys_memory[];

int main(int argc, char* argv[]) {
    if (argc != 2) {
        printf("NSCPU VMware r1\n");
        printf("  Usage: nscpu [binary file]\n");
        printf("         nscpu --help\n");
        printf("  Mem map: DATA[%06X:%06X], CODE[%06X:%06X]\n\n", 
            DAT_SIZE + DAT_ADDR - 1, DAT_ADDR, CODE_SIZE + CODE_ADDR - 1, CODE_ADDR
        );
        return 0;
    } else if (strcmp(strlwr(argv[1]), "--help") == 0) {
        printf("\n%s\n\n", help_str);
        return 0;
    }

    FILE* file;
    file = fopen(argv[1], "rb");
    if (file != NULL) {
        fseek(file, 0, SEEK_END);
        uint32_t len = ftell(file) % CODE_SIZE;
        uint8_t* code_addr = (uint8_t*) &sys_memory[CODE_ADDR];
        fseek(file, 0, SEEK_SET);
        fread(code_addr, 1, len, file);
        fclose(file);
        int ret = nscpu_run(code_addr, len);
        printf("\n[RET] Result: %d\n\n", ret);
    } else {
        printf("[ERR] File \"%s\" not found.\n\n", argv[1]);
        return 1;
    }

    return 0;
}
