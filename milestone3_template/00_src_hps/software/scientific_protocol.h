#ifndef SCIENTIFIC_PROTOCOL_H
#define SCIENTIFIC_PROTOCOL_H
#include <stdint.h>
#define SCI_HELLO      0x53430000u
#define SCI_INPUT_LOW  0x53410000u
#define SCI_INPUT_HIGH 0x53420000u
#define SCI_EXECUTE    0x53500000u
#define SCI_GET_RESULT 0x53510000u
#define SCI_B_LOW      0x53440000u
#define SCI_B_HIGH     0x53450000u
#define SCI_GET_REM    0x53520000u
#define SCI_VERSION    0x53434932u
struct scientific_input { int32_t argument; unsigned operation; int32_t operand_b; };
struct scientific_result { int32_t value; uint32_t error; int32_t remainder; };
typedef int (*scientific_transfer)(void *,uint32_t,uint32_t *);
int scientific_parse(const char *,struct scientific_input *);
int scientific_run(scientific_transfer,void *,const struct scientific_input *,struct scientific_result *);
const char *scientific_name(unsigned);
void scientific_format(char *,unsigned,int32_t);
#endif
