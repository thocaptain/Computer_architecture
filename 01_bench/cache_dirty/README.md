# Cache dirty-bit regression

Run from `bench_CPU` in WSL:

```sh
make test-cache-dirty VERILATOR=/home/lqhau/tools/oss-cad-suite/bin/verilator
```

The test uses the cache's public CPU and memory interfaces, with the CPU's
16-word lines and 8 direct-mapped slots. A small memory model accepts a word
every four clocks, so line transfers also exercise memory wait cycles.

Checks cover cold misses, clean eviction with no write-back, dirty read hits,
full-word and masked byte stores, dirty eviction to the victim's address,
preservation of untouched words, reload of written data, clearing dirty after
refill, store-miss allocation, and a store with an empty byte mask.

The sequence must finish with exactly 128 memory reads and 32 memory writes.
The separate CPU regression uses `TEST=all_suit` and `TEST=riscv_card` on modes
0 through 5 with their normal cache and memory-latency settings.
