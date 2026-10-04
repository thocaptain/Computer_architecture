# RV32I CPU Workspace

Workspace cho các phiên bản RV32I, testbench, chương trình assembly và project FPGA.

## Cấu trúc workspace

| Thư mục | Nội dung |
| --- | --- |
| `00_src/` | RTL: package, ALU, LSU, register file, memory, core single-cycle, pipeline và board wrappers. |
| `01_bench/` | SystemVerilog testbenches, drivers và scoreboards. |
| `02_test/asm/` | Chương trình assembly dùng để kiểm thử CPU. |
| `02_test/dump/` | ROM image dạng hex tương ứng; ví dụ `all_suit.mem`. |
| `03_script/` | Script tạo/chuyển đổi ROM và dữ liệu hỗ trợ. |
| `10_sim/` | Verilator simulation tổng quát; bench được chọn trong `10_sim/flist`. |
| `20_syn/` | Cấu hình tổng hợp, timing và pin assignment cho FPGA. |
| `30_demo/` | Các demo phần cứng. |
| `99_doc/` | Tài liệu và sơ đồ thiết kế. |
| `bench_CPU/` | Regression runner cho các ROM kiểm tra CPU; chọn core bằng `CORE_MODE`. |

## Regression trong `bench_CPU`

Chạy trong WSL từ thư mục `bench_CPU`. Dùng Verilator 5.x từ OSS CAD Suite; Verilator 4.028 trên hệ thống không hỗ trợ tùy chọn `--binary` của project.

```sh
cd /home/lqhau/RISC-V-RV32i-master/bench_CPU
make test VERILATOR=/home/lqhau/tools/oss-cad-suite/bin/verilator CORE_MODE=0 TEST=all_suit
```

Các chế độ `CORE_MODE`:

| Mode | Core | Mô tả |
| --- | --- | --- |
| `0` | `TOP_SINGLE_CYCLE` | Single-cycle; mặc định. |
| `1` | `rv32i_pipeline_stall` | Pipeline, stall khi có RAW hazard; không forwarding hoặc branch prediction. |
| `2` | `rv32i_pipeline_hazard` | Pipeline có forwarding và stall load-use; không branch prediction. |
| `3` | `TOP_SYNTH` | Pipeline đầy đủ hiện có, gồm tournament branch prediction. |

Ví dụ chạy từng stage:

```sh
make test VERILATOR=/home/lqhau/tools/oss-cad-suite/bin/verilator CORE_MODE=1 TEST=all_suit
make test VERILATOR=/home/lqhau/tools/oss-cad-suite/bin/verilator CORE_MODE=2 TEST=all_suit
make test VERILATOR=/home/lqhau/tools/oss-cad-suite/bin/verilator CORE_MODE=3 TEST=all_suit
```

`TEST` mặc định là `all_suit`. `make test` build nếu cần, chạy test và dump `wave_<test>.fst`. Mỗi mode dùng thư mục build riêng (`obj_dir_mode0` đến `obj_dir_mode3`). Mở waveform bằng:

```sh
make wave VERILATOR=/home/lqhau/tools/oss-cad-suite/bin/verilator CORE_MODE=3 TEST=all_suit
```

Cần cài `gtkwave` để dùng target `wave`. Dọn binary, waveform và log bằng `make clean`.

`all_suit` chạy 14 điều kiện kiểm tra. Thành công mong đợi `LEDR=0x00003FFF`, `LEDG=0x600D` ở core 32-bit; ở adapter `TOP_SYNTH`, LEDG chỉ rộng 9 bit nên runner nhận giá trị tương ứng `0x00D`.

## Simulation trong `10_sim`

```sh
cd /home/lqhau/RISC-V-RV32i-master/10_sim
PATH=/home/lqhau/tools/oss-cad-suite/bin:$PATH make sim
PATH=/home/lqhau/tools/oss-cad-suite/bin:$PATH make run
```

`make sim` build bench đang được chọn trong `10_sim/flist`; `make run` chạy executable đã build. Dùng `make wave` để mở waveform nếu GTKWave có sẵn.

## Project Quartus

Project Altera nằm trong `20_syn/altera/DE2-115`. Mở GUI bằng `open_de2_115_gui.cmd`; trong Quartus chọn **Processing > Start Compilation**. Có launcher `build_de2_115_single_cycle.cmd` để compile và lưu log/report/image vào `builds/<timestamp>/`.

QSF trên bản F: hiện được cấu hình cho **Cyclone II / EP2C35F672C6** với pin map DE2. Xác nhận đúng mã FPGA trên board trước khi nạp image. Quartus 13.0.1 SP1 compile được `.sof`, nhưng TimeQuest báo setup slack `-9.162 ns`. Ngoài ra wrapper hiện chọn `MEM_SRAM` nhưng các cổng SRAM đang để trống trong top; cần nối SRAM trước khi kỳ vọng các bài test dùng data memory chạy đúng trên board.

`20_syn/altera/DE10/` là scaffold; cần chọn chính xác model DE10 trước khi thêm device và pin assignment. `20_syn/xilinx/` dành cho project Xilinx.
# Computer_architecture
