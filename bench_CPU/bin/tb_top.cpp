// tb_all.cpp - run every self-checking assembly program in one binary and print a summary
//
// Each test gets a fresh model (own VerilatedContext) and its program is loaded at runtime
// through the +PROG=<file.mem> plusarg handled in 00_src/inst_mem.sv.
//
// Program protocol (02_test/asm/*.s):
//   LEDR (0x7000) = result on pass, failing test id on fail
//   LEDG (0x7010) = 0x600D pass / 0x0BAD fail   (written last)
//
// Usage (from bench_CPU/):
//   ./obj_dir_all/Vtop                      run all tests
//   ./obj_dir_all/Vtop gcd fibonacci        run only the named tests
//   ./obj_dir_all/Vtop +trace               also dump wave_<name>.fst per test
//   ./obj_dir_all/Vtop +verbose             print LEDR/LEDG changes while running
#include <stdio.h>
#include <string.h>
#include <string>
#include <vector>
#include <chrono>
#include <verilated.h>
#include <verilated_fst_c.h>
#include "Vtop.h"

static const unsigned int STATUS_PASS = 0x600D;
static const unsigned int STATUS_FAIL = 0x0BAD;
static const unsigned int STATUS_PASS_LED = STATUS_PASS & 0x1FF;
static const unsigned int STATUS_FAIL_LED = STATUS_FAIL & 0x1FF;
static const char *DUMP_DIR = "../02_test/dump/";

struct TestCase {
  const char   *name;
  unsigned int  expected_ledr;
  vluint64_t    max_cycles;
  const char   *description;
};

static const TestCase TESTS[] = {
  {"sum_array",   0x000013BA,  10000, "sum 1..100 from data memory"},
  {"factorial",   0x1C8CFC00,  50000, "recursive 12! with software MUL"},
  {"fibonacci",   0x00000262, 500000, "recursive fib(15) + iterative fib(30)"},
  {"gcd",         0x00000015, 100000, "Euclid gcd(1071,462) with software DIVU"},
  {"bubble_sort", 0x005AFFF9,  50000, "bubble sort 10 signed words"},
  {"prime_sieve", 0x00006119,  50000, "sieve of Eratosthenes up to 100"},
  {"matrix_mul",  0x0000026D,  50000, "3x3 matrix multiply"},
  {"bit_ops",     0x1E6A2C48,  50000, "popcount, bit reverse, shift/compare"},
  {"all_suit",    0x00003FFF, 1000000, "all 14 checks in one program"},
};
static const int NUM_TESTS = sizeof(TESTS) / sizeof(TESTS[0]);

enum Status { ST_PASS, ST_FAIL, ST_SELF_FAIL, ST_TIMEOUT, ST_BAD_LEDG, ST_SKIP };

static const char *status_str(Status s) {
  switch (s) {
    case ST_PASS:      return "\033[1;32mPASS\033[0m    ";
    case ST_FAIL:      return "\033[1;31mMISMATCH\033[0m";
    case ST_SELF_FAIL: return "\033[1;31mSELFFAIL\033[0m";
    case ST_TIMEOUT:   return "\033[1;31mTIMEOUT\033[0m ";
    case ST_BAD_LEDG:  return "\033[1;31mBADLEDG\033[0m ";
    default:           return "\033[1;33mSKIP\033[0m    ";
  }
}

struct Result {
  Status       status;
  vluint64_t   cycles;
  unsigned int ledr;
  unsigned int ledg;
  unsigned int last_pc;
  unsigned int ledr_writes;   // number of LEDR value changes observed
  double       wall_ms;
  std::string  note;
};

static bool file_exists(const std::string &path) {
  FILE *f = fopen(path.c_str(), "r");
  if (!f) return false;
  fclose(f);
  return true;
}

static Result run_test(const TestCase &tc, const char *argv0, bool trace, bool verbose) {
  Result r = {ST_SKIP, 0, 0, 0, 0, 0, 0.0, ""};

  std::string mem_path = std::string(DUMP_DIR) + tc.name + ".mem";
  if (!file_exists(mem_path)) {
    r.note = "missing " + mem_path;
    return r;
  }

  std::string prog_arg = "+PROG=" + mem_path;
  const char *args[] = {argv0, prog_arg.c_str()};

  VerilatedContext *ctx = new VerilatedContext;
  ctx->commandArgs(2, args);
  ctx->traceEverOn(trace);
  Vtop *dut = new Vtop(ctx);

  VerilatedFstC *vtrace = nullptr;
  if (trace) {
    vtrace = new VerilatedFstC;
    dut->trace(vtrace, 2);
    vtrace->open((std::string("wave_") + tc.name + ".fst").c_str());
  }

  auto t0 = std::chrono::steady_clock::now();

  dut->io_sw_i = 0;
  dut->clk_i   = 1;
  dut->rst_ni  = 0;
  dut->eval();
  if (vtrace) vtrace->dump(0);

  vluint64_t cycle = 0;
  unsigned int prev_ledr = 0;
  while (cycle < tc.max_cycles && dut->io_ledg_o == 0) {
    dut->rst_ni = (cycle < 2) ? 0 : 1;

    dut->clk_i = 0;
    dut->eval();
    if (vtrace) vtrace->dump(cycle * 10 + 5);

    dut->clk_i = 1;
    dut->eval();
    if (vtrace) vtrace->dump(cycle * 10 + 10);

    cycle++;

    if (dut->io_ledr_o != prev_ledr) {
      r.ledr_writes++;
      if (verbose)
        printf("    [%-11s] cycle %8llu: LEDR 0x%08X -> 0x%08X (PC 0x%08X)\n", tc.name,
               static_cast<unsigned long long>(cycle), prev_ledr, dut->io_ledr_o,
               dut->pc_debug_o);
      prev_ledr = dut->io_ledr_o;
    }
  }

  if (vtrace) {
    dut->clk_i = 0;
    dut->eval();
    vtrace->dump(cycle * 10 + 5);
    dut->clk_i = 1;
    dut->eval();
    vtrace->dump(cycle * 10 + 10);
  }

  auto t1 = std::chrono::steady_clock::now();
  r.wall_ms = std::chrono::duration<double, std::milli>(t1 - t0).count();
  r.cycles  = cycle;
  r.ledr    = dut->io_ledr_o;
  r.ledg    = dut->io_ledg_o;
  r.last_pc = dut->pc_debug_o;

  char buf[128];
  if (r.ledg == 0) {
    r.status = ST_TIMEOUT;
    snprintf(buf, sizeof(buf), "no LEDG after %llu cycles, PC=0x%08X",
             static_cast<unsigned long long>(cycle), r.last_pc);
  } else if (r.ledg == STATUS_FAIL || r.ledg == STATUS_FAIL_LED) {
    r.status = ST_SELF_FAIL;
    snprintf(buf, sizeof(buf), "program check failed at test id %u", r.ledr);
  } else if (r.ledg != STATUS_PASS && r.ledg != STATUS_PASS_LED) {
    r.status = ST_BAD_LEDG;
    snprintf(buf, sizeof(buf), "unexpected LEDG=0x%08X", r.ledg);
  } else if (r.ledr != tc.expected_ledr) {
    r.status = ST_FAIL;
    snprintf(buf, sizeof(buf), "LEDR=0x%08X expected 0x%08X", r.ledr, tc.expected_ledr);
  } else {
    r.status = ST_PASS;
    buf[0] = '\0';
  }
  r.note = buf;

  dut->final();
  if (vtrace) {
    vtrace->close();
    delete vtrace;
  }
  delete dut;
  delete ctx;
  return r;
}

int main(int argc, char **argv) {
  bool trace = false;
  bool verbose = false;
  std::vector<std::string> filter;
  for (int i = 1; i < argc; i++) {
    if (!strcmp(argv[i], "+trace"))        trace = true;
    else if (!strcmp(argv[i], "+verbose")) verbose = true;
    else if (argv[i][0] != '+' && argv[i][0] != '-') filter.push_back(argv[i]);
  }

  std::vector<int> selected;
  for (int i = 0; i < NUM_TESTS; i++) {
    if (filter.empty()) { selected.push_back(i); continue; }
    for (const auto &f : filter)
      if (f == TESTS[i].name) { selected.push_back(i); break; }
  }
  if (selected.empty()) {
    printf("No matching tests. Available:");
    for (int i = 0; i < NUM_TESTS; i++) printf(" %s", TESTS[i].name);
    printf("\n");
    return 1;
  }

  printf("\n=============================== RV32I REGRESSION ===============================\n");
  std::vector<Result> results;
  for (int idx : selected) {
    const TestCase &tc = TESTS[idx];
    printf("[RUN ] %-12s %s\n", tc.name, tc.description);
    fflush(stdout);
    Result r = run_test(tc, argv[0], trace, verbose);
    printf("[%s] %-12s %8llu cycles  %s\n", status_str(r.status), tc.name,
           static_cast<unsigned long long>(r.cycles), r.note.c_str());
    results.push_back(r);
  }

  int n_pass = 0, n_fail = 0, n_skip = 0;
  vluint64_t total_cycles = 0;
  printf("\n------------------------------------ SUMMARY -----------------------------------\n");
  printf("%-12s %-8s %10s %10s %10s %6s %9s %9s\n",
         "TEST", "STATUS", "CYCLES", "LEDR", "EXPECTED", "LEDG", "@27MHz ms", "wall ms");
  printf("--------------------------------------------------------------------------------\n");
  for (size_t i = 0; i < results.size(); i++) {
    const TestCase &tc = TESTS[selected[i]];
    const Result &r = results[i];
    if (r.status == ST_PASS) n_pass++;
    else if (r.status == ST_SKIP) n_skip++;
    else n_fail++;
    total_cycles += r.cycles;
    printf("%-12s %s %10llu 0x%08X 0x%08X %6X %9.3f %9.1f\n", tc.name, status_str(r.status),
           static_cast<unsigned long long>(r.cycles), r.ledr, tc.expected_ledr, r.ledg,
           (double)r.cycles / 27000.0, r.wall_ms);
  }
  printf("--------------------------------------------------------------------------------\n");
  printf("Total: %zu  \033[1;32mPass: %d\033[0m  \033[1;31mFail: %d\033[0m  \033[1;33mSkip: %d\033[0m"
         "  Cycles: %llu\n",
         results.size(), n_pass, n_fail, n_skip, static_cast<unsigned long long>(total_cycles));

  for (size_t i = 0; i < results.size(); i++)
    if (results[i].status != ST_PASS && !results[i].note.empty())
      printf("  - %-12s %s\n", TESTS[selected[i]].name, results[i].note.c_str());
  printf("================================================================================\n\n");

  return (n_fail == 0 && n_pass > 0) ? 0 : 1;
}