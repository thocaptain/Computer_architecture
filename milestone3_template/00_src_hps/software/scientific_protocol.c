#include "scientific_protocol.h"
#include <ctype.h>
#include <errno.h>
#include <stdlib.h>
#include <inttypes.h>
#include <stdio.h>
#include <string.h>

static const char *spaces(const char *p) {
    while (isspace((unsigned char)*p)) ++p;
    return p;
}
const char *scientific_name(unsigned operation) {
    static const char *names[]={"exp","sin","cos","+","-","*","/"};
    return operation<7 ? names[operation] : "?";
}
int scientific_parse(const char *text,struct scientific_input *out) {
    const char *p=spaces(text);
    unsigned operation;
    if (!strncmp(p,"exp",3)) operation=0;
    else if (!strncmp(p,"sin",3)) operation=1;
    else if (!strncmp(p,"cos",3)) operation=2;
    else {
        char *end;
        errno=0;
        long long a=strtoll(p,&end,10);
        if (errno || end==p || a<INT32_MIN || a>INT32_MAX) return -1;
        p=spaces(end);
        const char *symbols="+-*/";
        const char *symbol=strchr(symbols,*p);
        if (!*p || !symbol) return -1;
        operation=3+(unsigned)(symbol-symbols);
        p=spaces(p+1); errno=0;
        long long b=strtoll(p,&end,10);
        if (errno || end==p || *spaces(end) || b<INT32_MIN || b>INT32_MAX) return -1;
        *out=(struct scientific_input){(int32_t)a,operation,(int32_t)b};
        return 0;
    }
    p+=3;
    if (!isspace((unsigned char)*p)) return -1;
    p=spaces(p);
    int negative=0;
    if (*p=='-' || *p=='+') negative=*p++=='-';
    uint64_t whole=0, fraction=0;
    unsigned digits=0, places=0;
    while (isdigit((unsigned char)*p)) {
        whole=whole*10+(unsigned)(*p++-'0');
        if (whole>2147483) return -1;
        ++digits;
    }
    if (*p=='.') {
        ++p;
        while (isdigit((unsigned char)*p)) {
            if (places==3) return -1;
            fraction=fraction*10+(unsigned)(*p++-'0');
            ++places; ++digits;
        }
    }
    if (!digits || *spaces(p)) return -1;
    while (places++<3) fraction*=10;
    uint64_t magnitude=whole*1000+fraction;
    if (magnitude>(negative ? 2147483648ull : 2147483647ull)) return -1;
    int64_t value=negative ? -(int64_t)magnitude : (int64_t)magnitude;
    int64_t limit=operation==0 ? 9000 : 360000000;
    if (value < -limit || value > limit) return -1;
    out->argument=(int32_t)value;
    out->operation=operation;
    out->operand_b=0;
    return 0;
}
void scientific_format(char *output,unsigned size,int32_t value) {
    int64_t magnitude=value;
    if (magnitude<0) magnitude=-magnitude;
    snprintf(output,size,"%s%" PRId64 ".%03" PRId64,value<0 ? "-" : "",magnitude/1000,magnitude%1000);
}
int scientific_run(scientific_transfer transfer,void *context,
                   const struct scientific_input *input,struct scientific_result *out) {
    uint32_t response, argument=(uint32_t)input->argument;
    out->value=0; out->error=0; out->remainder=0;
    if (transfer(context,SCI_HELLO,&response)) return -1;
    if (response!=SCI_VERSION) return -2;
    const uint32_t commands[]={SCI_INPUT_LOW|(argument&0xffffu),SCI_INPUT_HIGH|(argument>>16)};
    for (unsigned i=0;i<2;++i) {
        if (transfer(context,commands[i],&response)) return -1;
        if (response) return -2;
    }
    if (input->operation>=3) {
        uint32_t b=(uint32_t)input->operand_b;
        const uint32_t halves[]={SCI_B_LOW|(b&0xffffu),SCI_B_HIGH|(b>>16)};
        for (unsigned i=0;i<2;++i) {
            if (transfer(context,halves[i],&response)) return -1;
            if (response) return -2;
        }
    }
    if (transfer(context,SCI_EXECUTE|input->operation,&response)) return -1;
    if (response>4 || response==3) return -2;
    out->error=response;
    if (response) return 0;
    if (transfer(context,SCI_GET_RESULT,&response)) return -1;
    memcpy(&out->value,&response,sizeof response);
    if (input->operation>=3) {
        if (transfer(context,SCI_GET_REM,&response)) return -1;
        memcpy(&out->remainder,&response,sizeof response);
    }
    return 0;
}
