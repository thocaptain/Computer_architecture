#include "scientific_protocol.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
struct mock { unsigned index; uint32_t version,error; unsigned binary; };
static int exchange(void *context,uint32_t command,uint32_t *response) {
    struct mock *mock=context;
    const uint32_t unary[]={SCI_HELLO,SCI_INPUT_LOW|0x8ad0,SCI_INPUT_HIGH|0xffff,SCI_EXECUTE|1,SCI_GET_RESULT};
    const uint32_t binary[]={SCI_HELLO,SCI_INPUT_LOW|0xffef,SCI_INPUT_HIGH|0xffff,SCI_B_LOW|5,SCI_B_HIGH,SCI_EXECUTE|6,SCI_GET_RESULT,SCI_GET_REM};
    unsigned execute=mock->binary ? 5 : 3;
    assert(mock->index<(mock->binary ? 8u : 5u));
    assert(command==(mock->binary ? binary : unary)[mock->index]);
    *response=mock->index==0 ? mock->version : mock->index==execute ? mock->error :
              mock->index==execute+1 ? (uint32_t)(mock->binary ? -3 : -500) :
              mock->index==execute+2 ? (uint32_t)-2 : 0;
    ++mock->index;
    return 0;
}
int main(void) {
    const char *valid[]={"exp 1.5","exp -9","sin 30","cos -360000.000","sin .5","exp +0.001","cos 1."};
    const int32_t arguments[]={1500,-9000,30000,-360000000,500,1,1000};
    const unsigned operations[]={0,0,1,2,1,0,2};
    struct scientific_input input;
    for (unsigned i=0;i<sizeof valid/sizeof valid[0];++i) {
        assert(scientific_parse(valid[i],&input)==0);
        assert(input.argument==arguments[i] && input.operation==operations[i]);
    }
    const char *invalid[]={"","exp","exp1","exp 9.001","exp -9.001","sin 360000.001","sin -360000.001","tan 30","sin 30rad","sin 0.0001","exp 1e2","exp .","exp +","cos 99999999999999","cos 1 2"};
    for (unsigned i=0;i<sizeof invalid/sizeof invalid[0];++i) assert(scientific_parse(invalid[i],&input)!=0);
    const char *arithmetic[]={"12 + 34","-17 / 5","-2147483648*-1","1--2","2147483647-2147483647"};
    const int32_t aa[]={12,-17,INT32_MIN,1,INT32_MAX},bb[]={34,5,-1,-2,INT32_MAX};
    const unsigned ops[]={3,6,5,4,4};
    for (unsigned i=0;i<5;++i) {
        assert(scientific_parse(arithmetic[i],&input)==0);
        assert(input.argument==aa[i] && input.operand_b==bb[i] && input.operation==ops[i]);
    }
    const char *bad[]={"1.5+2","2147483648+1","1+-2147483649","1+2+3","1/","2**3","1","0x10+1"};
    for (unsigned i=0;i<sizeof bad/sizeof bad[0];++i) assert(scientific_parse(bad[i],&input)!=0);
    char text[32];
    scientific_format(text,sizeof text,-1); assert(!strcmp(text,"-0.001"));
    scientific_format(text,sizeof text,8103084); assert(!strcmp(text,"8103.084"));
    scientific_format(text,sizeof text,INT32_MIN); assert(!strcmp(text,"-2147483.648"));
    struct scientific_result result;
    input=(struct scientific_input){-30000,1,0};
    struct mock mock={0,SCI_VERSION,0,0};
    assert(scientific_run(exchange,&mock,&input,&result)==0);
    assert(result.value==-500 && result.error==0 && mock.index==5);
    mock=(struct mock){0,SCI_VERSION,4,0};
    assert(scientific_run(exchange,&mock,&input,&result)==0 && result.error==4 && mock.index==4);
    mock=(struct mock){0,0x53434931,0,0};
    assert(scientific_run(exchange,&mock,&input,&result)==-2 && mock.index==1);
    input=(struct scientific_input){-17,6,5};
    mock=(struct mock){0,SCI_VERSION,0,1};
    assert(scientific_run(exchange,&mock,&input,&result)==0 && mock.index==8);
    assert(result.value==-3 && result.remainder==-2 && !result.error);
    for (unsigned error=1;error<=2;++error) {
        mock=(struct mock){0,SCI_VERSION,error,1};
        assert(scientific_run(exchange,&mock,&input,&result)==0 && mock.index==6 && result.error==error);
    }
    puts("PASS: scientific parser, fixed-point formatting, wire protocol and version checks");
    return 0;
}
