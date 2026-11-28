#ifndef CALCULATOR_PROTOCOL_H
#define CALCULATOR_PROTOCOL_H
#include <stdint.h>

#define CAL_HELLO       0xca000000u
#define CAL_A_LOW       0xca010000u
#define CAL_A_HIGH      0xca020000u
#define CAL_B_LOW       0xca030000u
#define CAL_B_HIGH      0xca040000u
#define CAL_EXECUTE     0xca100000u
#define CAL_GET_RESULT  0xca110000u
#define CAL_GET_REM     0xca120000u
#define CAL_VERSION     0x43414c31u

struct calculation {
    int32_t a, b;
    unsigned operation;
    char symbol;
};
struct calculation_result {
    int32_t value, remainder;
    uint32_t error;
};
typedef int (*calculator_transfer)(void *, uint32_t, uint32_t *);

/* Parse exactly one signed decimal A op B expression. No calculation on HPS. */
int calculator_parse(const char *, struct calculation *);
/* Returns 0 on exchange success, -1 transport error, -2 wrong firmware/protocol. */
int calculator_run(calculator_transfer, void *, const struct calculation *,
                   struct calculation_result *);
#endif
