#include "calculator_protocol.h"
#include <ctype.h>
#include <errno.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>

static const char *skip_space(const char *p) {
    while (isspace((unsigned char)*p)) ++p;
    return p;
}
static int operand(const char **text, int32_t *value) {
    char *end;
    const char *start = skip_space(*text);
    errno = 0;
    long long number = strtoll(start, &end, 10);
    if (end == start || errno || number < INT32_MIN || number > INT32_MAX) return -1;
    *value = (int32_t)number;
    *text = end;
    return 0;
}
int calculator_parse(const char *text, struct calculation *out) {
    struct calculation parsed;
    if (operand(&text, &parsed.a)) return -1;
    text = skip_space(text);
    parsed.symbol = *text;
    switch (*text) {
        case '+': parsed.operation = 0; break;
        case '-': parsed.operation = 1; break;
        case '*': parsed.operation = 2; break;
        case '/': parsed.operation = 3; break;
        default: return -1;
    }
    ++text;
    if (operand(&text, &parsed.b) || *skip_space(text)) return -1;
    *out = parsed;
    return 0;
}
static int ack(calculator_transfer transfer, void *context, uint32_t command) {
    uint32_t response;
    if (transfer(context, command, &response)) return -1;
    return response == 0 ? 0 : -2;
}
int calculator_run(calculator_transfer transfer, void *context,
                   const struct calculation *input, struct calculation_result *out) {
    uint32_t response, a = (uint32_t)input->a, b = (uint32_t)input->b;
    out->value = out->remainder = 0;
    out->error = 0;
    if (transfer(context, CAL_HELLO, &response)) return -1;
    if (response != CAL_VERSION) return -2;
    const uint32_t commands[] = {
        CAL_A_LOW | (a & 0xffffu), CAL_A_HIGH | (a >> 16),
        CAL_B_LOW | (b & 0xffffu), CAL_B_HIGH | (b >> 16)
    };
    for (unsigned i = 0; i < sizeof commands / sizeof commands[0]; ++i) {
        int status = ack(transfer, context, commands[i]);
        if (status) return status;
    }
    if (transfer(context, CAL_EXECUTE | input->operation, &response)) return -1;
    if (response > 2) return -2;
    out->error = response;
    if (response) return 0;
    if (transfer(context, CAL_GET_RESULT, &response)) return -1;
    memcpy(&out->value, &response, sizeof response);
    if (transfer(context, CAL_GET_REM, &response)) return -1;
    memcpy(&out->remainder, &response, sizeof response);
    return 0;
}
