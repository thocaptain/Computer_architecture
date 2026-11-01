// Strict full-CPU app runner. No masked status values are accepted on 32-bit cores.
#include <cstdio>
#include <cstring>
#include <string>
#include <vector>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vtop.h"
#include "../../02_test/Milestone1/apps/app05_config.h"
#ifndef CPU_CORE_MODE
#define CPU_CORE_MODE 0
#endif

struct App { const char* name; const char* rom; unsigned expected; unsigned long long timeout; };
static const App apps[] = {
    {"all_suit", "../02_test/dump/all_suit.mem", 0x3fff, 1000000},
    {"app05_instruction", "../02_test/Milestone1/apps/app05_instruction.mem", APP05_EXPECTED, APP05_TIMEOUT},
};
struct Result {
    const App* app;
    std::string status;
    unsigned long long cycles;
    unsigned ledr, ledg, pc;
};

static Result run(const App& app, const char* argv0) {
    Result result{&app, "TIMEOUT", 0, 0, 0, 0};
    FILE* rom = fopen(app.rom, "r");
    if (!rom) { result.status = "MISSING_ROM"; return result; }
    fclose(rom);
    VerilatedContext context;
    std::string program = std::string("+PROG=") + app.rom;
    const char* args[] = {argv0, program.c_str()};
    context.commandArgs(2, args);
    Vtop dut(&context);
    dut.io_sw_i = 0;
    dut.clk_i = 1;
    dut.rst_ni = 0;
    dut.eval();
    // Same reset sequence and cycle-count boundary as bench_CPU/bin/tb_top.cpp.
    while (result.cycles < app.timeout && dut.io_ledg_o == 0 && !context.gotFinish()) {
        dut.rst_ni = result.cycles < 2 ? 0 : 1;
        dut.clk_i = 0; dut.eval();
        dut.clk_i = 1; dut.eval();
        result.cycles++;
    }
    result.ledr = dut.io_ledr_o;
    result.ledg = dut.io_ledg_o;
    result.pc = dut.pc_debug_o;
    const unsigned pass = CPU_CORE_MODE == 3 ? 0x00d : 0x600d;
    const unsigned fail = CPU_CORE_MODE == 3 ? 0x1ad : 0x0bad;
    if (result.ledg == fail) result.status = "SELF_FAIL";
    else if (result.ledg == pass)
        result.status = result.ledr == app.expected ? "PASS" : "LEDR_MISMATCH";
    else if (result.ledg != 0) result.status = "BAD_LEDG";
    dut.final();
    return result;
}

int main(int argc, char** argv) {
    const char* json_path = nullptr;
    std::vector<std::string> selected;
    for (int arg = 1; arg < argc; arg++) {
        if (!strcmp(argv[arg], "--json") && arg+1 < argc) json_path = argv[++arg];
        else selected.emplace_back(argv[arg]);
    }
    std::vector<Result> results;
    bool success = true;
    for (const App& app : apps) {
        bool enabled = selected.empty();
        for (const std::string& name : selected) if (name == app.name) enabled = true;
        if (!enabled) continue;
        printf("[RUN] %s core=%d\n", app.name, CPU_CORE_MODE);
        fflush(stdout);
        Result result = run(app, argv[0]);
        printf("APP %s %s cycles=%llu LEDR=0x%08x expected=0x%08x LEDG=0x%04x PC=0x%08x\n",
               app.name, result.status.c_str(), result.cycles, result.ledr, app.expected, result.ledg, result.pc);
        success = success && result.status == "PASS";
        results.push_back(result);
    }
    if (results.empty()) { fprintf(stderr, "No matching apps\n"); return 2; }
    if (json_path) {
        FILE* file = fopen(json_path, "w");
        if (!file) { perror(json_path); return 2; }
        fprintf(file, "[\n");
        for (size_t idx = 0; idx < results.size(); idx++) {
            const Result& r = results[idx];
            fprintf(file, "  {\"app\":\"%s\",\"core\":%d,\"status\":\"%s\",\"cycles\":%llu,\"ledr\":%u,\"expected_ledr\":%u,\"ledg\":%u,\"pc\":%u}%s\n",
                    r.app->name, CPU_CORE_MODE, r.status.c_str(), r.cycles, r.ledr,
                    r.app->expected, r.ledg, r.pc, idx+1 == results.size() ? "" : ",");
        }
        fprintf(file, "]\n"); fclose(file);
    }
    return success ? 0 : 1;
}
