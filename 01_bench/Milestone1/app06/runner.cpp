#include "Vapp06_de2_115.h"
#include "verilated.h"
#include <array>
#include <cstdint>
#include <cstdio>
#include <stdexcept>
#include <string>

// Exercise the physical wrapper, with accelerated firmware time and debounce.
// This verifies digital behavior; optical LED/LCD and wall-clock tests remain manual.
struct Bench {
    Vapp06_de2_115 dut;
    uint64_t cycles=0;
    unsigned addr=0, lcd_writes=0;
    std::array<char,128> lcd;
    bool old_en=false;
    unsigned red_seen=0,green_seen=0;
    unsigned checks=0;
    Bench() { lcd.fill(' '); dut.CLOCK_50=0; dut.KEY=15; dut.SW=0; }
    void run(unsigned n) {
        // one CPU clock = ten CLOCK_50 cycles
        for (unsigned i=0;i<n*10;i++) {
            dut.CLOCK_50=0; dut.eval();
            dut.CLOCK_50=1; dut.eval();
            if (old_en && !dut.LCD_EN && dut.LCD_ON) {
                if (dut.LCD_RW) throw std::runtime_error("LCD unexpectedly reads");
                if (dut.LCD_RS) { lcd[addr & 127]=dut.LCD_DATA; addr=(addr+1)&127; }
                else if (dut.LCD_DATA & 128) addr=dut.LCD_DATA & 127;
                else if (dut.LCD_DATA==1) { lcd.fill(' '); addr=0; }
                lcd_writes++;
            }
            old_en=dut.LCD_EN;
            red_seen |= dut.LEDR;
            green_seen |= dut.LEDG;
        }
        cycles+=n;
    }
    void check(bool ok,const char* what) {
        checks++;
        std::printf("%s %s\n",ok?"PASS":"FAIL",what);
        if (!ok) throw std::runtime_error(what);
    }
    unsigned hex() {
        static const unsigned seg[16]={0x40,0x79,0x24,0x30,0x19,0x12,0x02,0x78,
                                       0x00,0x10,0x08,0x03,0x46,0x21,0x06,0x0e};
        unsigned raw[8]={dut.HEX0,dut.HEX1,dut.HEX2,dut.HEX3,dut.HEX4,dut.HEX5,dut.HEX6,dut.HEX7};
        unsigned value=0;
        for (int i=0;i<8;i++) {
            int digit=-1;
            for(int d=0;d<16;d++) if(raw[i]==seg[d]) digit=d;
            if(digit<0) throw std::runtime_error("Invalid 7seg encoding");
            value |= unsigned(digit)<<(i*4);
        }
        return value;
    }
    void select(unsigned mode) { dut.KEY=15; dut.SW=mode<<15; run(8000); }
    void press(unsigned key) { dut.KEY=15 & ~(1u<<key); run(2000); dut.KEY=15; run(2000); }
    void pass_status(unsigned mode,unsigned status) {
        unsigned h=hex();
        if((h>>28)!=mode || ((h>>24)&15)!=status)
            std::printf("DEBUG HEX=%08x LEDG=%03x LCD=%.16s / %.16s\n",h,dut.LEDG,lcd.data(),lcd.data()+64);
        check((h>>28)==mode && ((h>>24)&15)==status,"mode and expected PASS status on HEX");
    }
};

int main(int argc,char**argv) {
    Verilated::commandArgs(argc,argv);
    try {
        Bench b;
        b.dut.KEY=7; b.run(30); b.dut.KEY=15; b.run(10000);
        b.check(b.lcd_writes>40,"boot initializes LCD and writes menu");
        b.check(std::string(b.lcd.data(),16)=="0 LED OFF/ON/RUN","LCD mode 0 title");
        b.run(30000);
        b.check(b.red_seen==0x3ffff && b.green_seen==0x1ff,"LED patterns exercise all 27 outputs");
        b.press(2); b.pass_status(0,1);
        b.select(1);
        b.dut.SW=(1u<<15)|0x1555; b.run(2000);
        b.check(b.dut.LEDR==((1u<<15)|0x1555),"switches mirror to corresponding red LEDs");
        b.dut.SW=(1u<<15)|0x7fff; b.run(3000); b.pass_status(1,2);
        b.press(0); b.pass_status(1,0);
        b.dut.SW=1u<<15; b.run(2000); b.dut.SW=(1u<<15)|0x7fff; b.run(2000);
        b.pass_status(1,2);
        b.select(2);
        b.dut.KEY=14; b.run(1); b.dut.KEY=15; b.run(500);
        b.check((b.hex()&0xffffff)==0,"short button glitch rejected by debounce");
        b.dut.KEY=14; b.run(5000);
        b.check((b.hex()&0xffffff)==1,"held KEY0 produces exactly one event");
        b.dut.KEY=15; b.run(2000); b.press(1); b.press(2);
        b.check((b.hex()&0xffffff)==0x010101,"three independent button counters");
        b.pass_status(2,2);
        b.select(3);
        unsigned digits=0;
        for(unsigned i=0;i<400;i++) {
            b.run(80); auto h=b.hex();
            bool repeated=true; for(int d=1;d<8;d++) if(((h>>(4*d))&15)!=(h&15)) repeated=false;
            if(repeated) digits |= 1u<<(h&15);
        }
        b.check(digits==0xffff,"all eight HEX displays show each digit 0..F");
        b.press(2); b.check((b.dut.LEDG & 0x40)!=0,"manual HEX confirmation sets PASS");
        b.select(4);
        auto seconds=b.hex()&0xffffff; b.run(10000);
        b.check((b.hex()&0xffffff)>seconds,"MMIO timer advances displayed seconds");
        b.press(2); b.pass_status(4,1);
        b.select(5); b.run(700000); b.pass_status(5,2);
        b.check((b.hex()&0xffffff)==0x1f00,"RAM patterns and byte/halfword tests pass for 7936 bytes");
        b.select(6);
        b.check(std::string(b.lcd.data(),16)=="0123456789ABCDEF","LCD character test row");
        std::string count(b.lcd.data()+70,4); b.run(3000);
        b.check(std::string(b.lcd.data()+70,4)!=count,"LCD dynamic counter updates");
        b.press(2); b.pass_status(6,1);
        b.select(7);
        b.check((b.hex()&127)==127,"summary records PASS for all seven modes");
        b.select(0); b.check(std::string(b.lcd.data(),16)=="0 LED OFF/ON/RUN","menu loops from summary back to LED test");
        b.dut.KEY=7; b.run(100); b.dut.KEY=15; b.select(7);
        b.check((b.hex()&127)==0,"KEY3 reset clears saved PASS results and restarts CPU");
        std::printf("APP06 PASS: %u checks, %llu CPU cycles (accelerated timing ROM)\n",b.checks,(unsigned long long)b.cycles);
        return 0;
    } catch(const std::exception &e) { std::fprintf(stderr,"APP06 FAIL: %s\n",e.what()); return 1; }
}
