// End-to-end, self-checking tests derived from 99_doc/RISCV_CARD.pdf.
// Only public CPU/MMIO signals are used, so the same tests run on modes 0-5.
#include <cstdint>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>
#include <sys/stat.h>
#include <verilated.h>
#include <verilated_fst_c.h>
#include "Vtop.h"

struct CardCase {
    std::string name, group, action, rom, note;
    uint32_t id;
    uint64_t max_cycles;
};

static std::vector<std::string> split(const std::string& line) {
    std::vector<std::string> fields;
    size_t start = 0, end;
    while ((end = line.find('\t', start)) != std::string::npos) {
        fields.push_back(line.substr(start, end - start));
        start = end + 1;
    }
    fields.push_back(line.substr(start));
    return fields;
}

static std::string quoted(const std::string& text) {
    std::string out = "\"";
    for (char ch : text) out += ch == '"' ? "\"\"" : std::string(1, ch);
    return out + "\"";
}

int main(int argc, char** argv) {
    int mode = 0;
    bool trace = false;
    for (int i = 1; i < argc; ++i) {
        const std::string arg(argv[i]);
        if (arg.compare(0, 6, "+MODE=") == 0) mode = std::stoi(arg.substr(6));
        else if (arg == "+trace") trace = true;
        else if (arg != "riscv_card") {
            std::cerr << "Unknown argument: " << arg << '\n';
            return 2;
        }
    }
    if (mode < 0 || mode > 5) {
        std::cerr << "CORE_MODE must be 0..5\n";
        return 2;
    }
    std::ifstream manifest("tests/riscv_card/generated/manifest.tsv");
    if (!manifest) {
        std::cerr << "Missing card ROMs; run make riscv-card-roms first.\n";
        return 2;
    }
    mkdir("results", 0755);
    mkdir("results/riscv_card", 0755);
    const std::string directory = "results/riscv_card/mode" + std::to_string(mode);
    mkdir(directory.c_str(), 0755);
    std::ofstream report(directory + "/results.csv");
    if (!report) {
        std::cerr << "Cannot write card result CSV\n";
        return 2;
    }
    report << "case,group,status,cycles,case_id,ledr,ledg,note\n";
    std::string line;
    std::getline(manifest, line); // header
    unsigned passed = 0, failed = 0, unsupported = 0;
    uint64_t total_cycles = 0;
    const uint32_t expected_status = mode == 3 ? (0x600D & 0x1FF) : 0x600D;
    while (std::getline(manifest, line)) {
        if (!line.empty() && line.back() == '\r') line.pop_back();
        const auto fields = split(line);
        if (fields.size() != 7) {
            std::cerr << "Malformed manifest row: " << line << '\n';
            return 2;
        }
        CardCase test{fields[0], fields[1], fields[2], fields[3], fields[6],
                      static_cast<uint32_t>(std::stoul(fields[4])), std::stoull(fields[5])};
        if (test.action == "UNSUPPORTED") {
            ++unsupported;
            report << quoted(test.name) << ',' << quoted(test.group)
                   << ",UNSUPPORTED,0,0,0,0," << quoted(test.note) << '\n';
            continue;
        }
        if (test.action != "TEST" || !std::ifstream(test.rom)) {
            std::cerr << "Unknown action or missing ROM: " << test.name << '\n';
            return 2;
        }
        VerilatedContext context;
        const std::string program = "+PROG=" + test.rom;
        const char* args[] = {argv[0], program.c_str()};
        context.commandArgs(2, args);
        context.traceEverOn(trace);
        Vtop dut(&context);
        VerilatedFstC waveform;
        if (trace) {
            dut.trace(&waveform, 2);
            waveform.open((directory + "/" + test.name + ".fst").c_str());
        }
        dut.io_sw_i = 0;
        dut.clk_i = 1;
        dut.rst_ni = 0;
        dut.eval();
        if (trace) waveform.dump(0);
        uint64_t cycles = 0;
        while (cycles < test.max_cycles && dut.io_ledg_o == 0 && !context.gotFinish()) {
            dut.rst_ni = cycles < 2 ? 0 : 1;
            dut.clk_i = 0;
            dut.eval();
            if (trace) waveform.dump(cycles * 10 + 5);
            dut.clk_i = 1;
            dut.eval();
            if (trace) waveform.dump(cycles * 10 + 10);
            ++cycles;
        }
        const bool ok = dut.io_ledg_o == expected_status && dut.io_ledr_o == test.id;
        const std::string status = ok ? "PASS" : dut.io_ledg_o == 0 ? "TIMEOUT" : "FAIL";
        const std::string note = ok ? "" : "See tests/riscv_card/generated/" + test.name + ".s; LEDR identifies the failing check";
        if (ok) ++passed;
        else ++failed;
        total_cycles += cycles;
        std::cout << '[' << status << "] " << std::left << std::setw(37) << test.name
                  << std::right << std::setw(7) << cycles << " cycles"
                  << " LEDR=0x" << std::hex << dut.io_ledr_o
                  << " LEDG=0x" << dut.io_ledg_o << std::dec << '\n';
        report << quoted(test.name) << ',' << quoted(test.group) << ',' << status << ','
               << cycles << ',' << test.id << ',' << dut.io_ledr_o << ',' << dut.io_ledg_o
               << ',' << quoted(note) << '\n';
        dut.final();
        if (trace) waveform.close();
    }
    std::cout << "RISCV_CARD mode=" << mode << " PASS=" << passed << " FAIL=" << failed
              << " UNSUPPORTED=" << unsupported << " CYCLES=" << total_cycles << '\n'
              << "Report: " << directory << "/results.csv\n";
    return failed == 0 && passed > 0 ? 0 : 1;
}
