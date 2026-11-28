#include "calculator_protocol.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>

struct mock {
    const uint32_t *commands;
    const uint32_t *responses;
    unsigned count, position;
    int fail_at;
};
static int exchange(void *context, uint32_t command, uint32_t *response) {
    struct mock *mock = context;
    assert(mock->position < mock->count);
    assert(command == mock->commands[mock->position]);
    if ((int)mock->position == mock->fail_at) return -1;
    *response = mock->responses[mock->position++];
    return 0;
}
int main(void) {
    const char *valid[] = {"12 + 34", "-12*5", "1--2", "-2147483648 / -1", "2147483647+0", "  +12 / +5\n"};
    const int32_t a[] = {12,-12,1,INT32_MIN,INT32_MAX,12};
    const int32_t b[] = {34,5,-2,-1,0,5};
    const unsigned operations[] = {0,2,1,3,0,3};
    struct calculation parsed;
    for (unsigned i=0; i<sizeof valid/sizeof valid[0]; ++i) {
        assert(calculator_parse(valid[i], &parsed)==0);
        assert(parsed.a==a[i] && parsed.b==b[i] && parsed.operation==operations[i]);
    }
    const char *invalid[] = {"", "q", "1", "1+", "1+2+3", "1.5+2", "1%2", "2147483648+0", "-2147483649+0", "999999999999999999999+1", "1+2junk", "0x12+1"};
    for (unsigned i=0; i<sizeof invalid/sizeof invalid[0]; ++i)
        assert(calculator_parse(invalid[i], &parsed)!=0);

    const uint32_t commands[] = {CAL_HELLO, CAL_A_LOW|0xfff4, CAL_A_HIGH|0xffff,
        CAL_B_LOW|5, CAL_B_HIGH, CAL_EXECUTE|3, CAL_GET_RESULT, CAL_GET_REM};
    const uint32_t responses[] = {CAL_VERSION,0,0,0,0,0,0xfffffffe,0xfffffffe};
    struct mock mock={commands,responses,8,0,-1};
    struct calculation input={-12,5,3,'/'};
    struct calculation_result result;
    assert(calculator_run(exchange,&mock,&input,&result)==0);
    assert(result.value==-2 && result.remainder==-2 && result.error==0 && mock.position==8);

    uint32_t error_responses[8];
    memcpy(error_responses,responses,sizeof responses);
    error_responses[5]=1;
    mock=(struct mock){commands,error_responses,8,0,-1};
    assert(calculator_run(exchange,&mock,&input,&result)==0);
    assert(result.error==1 && result.value==0 && result.remainder==0 && mock.position==6);

    error_responses[0]=CAL_HELLO+1; // The old input+1 firmware must be rejected.
    mock=(struct mock){commands,error_responses,8,0,-1};
    assert(calculator_run(exchange,&mock,&input,&result)==-2 && mock.position==1);
    mock=(struct mock){commands,responses,8,0,3};
    assert(calculator_run(exchange,&mock,&input,&result)==-1);
    puts("PASS: signed expression parser, transport framing, firmware version and error handling");
    return 0;
}
