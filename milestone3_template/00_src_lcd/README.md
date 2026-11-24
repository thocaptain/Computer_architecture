# Bản source MCU Milestone 3 có LCD — DE2 Cyclone II

Đây là bản riêng được sao chép từ `../00_src`, thêm ngoại vi cho LCD ký tự 16x2 trên
DE2 Cyclone II EP2C35F672C6. Thư mục source gốc và project Quartus hiện tại không bị chuyển
sang bản LCD. Clock mặc định của bản này là 25 MHz, IMEM 4 KiB, DMEM 1 KiB.

## Thay đổi trong source

- `lcd_device.sv`: thanh ghi MMIO và handshake gửi byte tới `lcd_ctrl`.
- `lcd_ctrl.sv`: sao chép nguyên từ `../../00_src/lcd_ctrl.sv`, điều khiển trực tiếp DATA,
  RS, RW, EN và ON của LCD. BLON lấy từ thanh ghi vì module gốc không có cổng đèn nền.
- `simple_bus.sv`: thêm thiết bị số 8, giải mã trang địa chỉ 0x40006000.
- `milestone3.sv`: nối thiết bị LCD vào bus, xuất các tín hiệu LCD.
- `example_de2_wrapper.sv`: đưa tín hiệu ra cổng `LCD_DATA[7:0]`, `LCD_RS`, `LCD_RW`,
  `LCD_EN`, `LCD_ON`, `LCD_BLON`.
- `mcu_config.svh`: ảnh IMEM mặc định là `../apps/lcd_demo/lcd_demo.mem`, dùng đường dẫn
  UNC tuyệt đối tới repository hiện tại để Quartus Windows tìm được.
- `de2_base_pins.qsf`: pin clock, switch, nút, LED, HEX và GPIO khớp tên cổng của wrapper.
  GPIO[0..31] dùng 32 chân đầu của header GPIO_0 trên DE2.
- `lcd_pins_de2.qsf`: 13 pin LCD, theo file gán chân DE2 Cyclone II trong repository.
- `lcd_clock.sdc`: CLOCK_50 50 MHz, MCU_CLK chia 2 (25 MHz).
- `lcd_sources.qsf`: file gom danh sách source, pin và SDC để đưa vào project.

Các module vẫn có cùng tên với bản gốc, nên project chỉ chọn **một** thư mục source.
Top của bản LCD là `example_de2_wrapper`.

## Memory map LCD

| Địa chỉ | Tên | Chức năng |
|---|---|---|
| 0x40006000 | DATA | Bits [7:0] đưa ra LCD_DATA, bits còn lại đọc 0 |
| 0x40006004 | CTRL | Bit 0 RS, bit 1 SEND, bit 2 ON, bit 3 BLON |
| 0x40006008 | STATUS | Bit 0 READY, bit 1 BUSY; các bit khác đọc 0 |

DATA và CTRL hỗ trợ byte-enable và reset về 0. SEND là lệnh ghi 1, tự phát valid một
chu kỳ và luôn đọc lại bằng 0. STATUS chỉ đọc, mô tả trạng thái truyền của controller.
Các offset khác đọc 0 và bỏ qua ghi. Đầu vào RW của controller được buộc 0: chỉ ghi LCD.

```text
CPU -> simple_bus -> lcd_device (MMIO + handshake) -> lcd_ctrl -> LCD
```

DATA và RS được chốt khi nhận SEND hợp lệ và giữ ổn định trong suốt giao dịch.
BUSY bao gồm cả chu kỳ pending trước khi controller nhận valid. SEND lúc BUSY bị bỏ qua;
không có hàng đợi. Phần mềm cần chờ READY trước mỗi yêu cầu.

Ví dụ gửi ký tự ASCII khi LCD đã khởi tạo:

1. Chờ STATUS.READY=1.
2. Ghi mã ASCII vào DATA.
3. Ghi CTRL=15: ON=1, BLON=1, RS=1, SEND=1.
4. Chờ READY trở lại, rồi chờ LCD xử lý lệnh nội bộ trước lần gửi tiếp theo.

Với lệnh LCD, ghi CTRL=14 để gửi với RS=0. CPU không tự bật/tắt EN nữa.
`lcd_ctrl` tạo xung EN và timing giao tiếp; phần mềm thực hiện khởi tạo LCD, chọn dòng,
gửi ASCII và chờ thời gian xử lý lệnh. READY của controller không phải busy flag của LCD.
Module được đặt T_PERIOD_NS=40, T_AS_NS=80, T_PW_NS=480, T_CYCE_NS=1000 cho MCU 25 MHz.
Mẫu khởi tạo theo [datasheet HD44780U](https://cdn-shop.adafruit.com/datasheets/HD44780.pdf),
dùng delay bảo thủ: cấp nguồn chờ 50 ms, các lần function-set đầu chờ thêm 5 ms/1 ms,
controller tạo xung EN 480 ns, thao tác thường chờ thêm 50 us; clear/home chờ thêm 2 ms.
Timer đếm clock MCU, nên thay tần số phải đổi các hằng delay của phần mềm.

## Đưa vào Quartus

Nên tạo project/revision riêng cho bản LCD:

1. Chọn Family Cyclone II, device EP2C35F672C6.
2. Trong QSF của project, bỏ các dòng `SYSTEMVERILOG_FILE`, `SOURCE_FILE` và `SEARCH_PATH`
   đang trỏ tới `milestone3_template/00_src`; không thêm cả hai bản source.
3. Bỏ dòng SDC cũ và `source "de2_pin_assign.qsf"` cũ để dùng bộ pin/clock đi kèm bản này.
4. Thêm duy nhất dòng sau để lấy source, pin, clock và top:

   ```tcl
   source "//wsl.localhost/Ubuntu-20.04/home/lqhau/RISC-V-RV32i-master/milestone3_template/00_src_lcd/lcd_sources.qsf"
   ```

5. Để `SIM_ONLY` và `DMEM_USE_SRAM` không được định nghĩa cho cấu hình board mặc định.
6. Compile Quartus, xem timing 25 MHz rồi nạp `.sof` mới khi bạn sẵn sàng.

File LCD `.qsf` chỉ dành cho DE2 Cyclone II, không dùng với DE2-115 Cyclone IV.
SDC đi kèm chỉ khai báo clock; chưa bổ sung đầy đủ constraint giao tiếp I/O bên ngoài.
Việc đạt timing 25 MHz phải xác nhận bằng báo cáo build mới.

## Chương trình demo và cách dùng lại trong app

Ảnh IMEM mặc định là [lcd_demo.mem](../apps/lcd_demo/lcd_demo.mem). Sau khi reset,
chương trình khởi tạo LCD rồi ghi nội dung dự kiến:

```text
MCU LCD READY
RV32I @ 25 MHz
```

LEDG0 được bật khi phần mềm đã ghi xong các ký tự (không phải xác nhận phản hồi từ LCD).
SW vẫn được đọc và phản ánh trên LED đỏ. Demo không cần nhấn RUN.

Các routine trong `../apps/lcd_demo/lcd_demo.s` có thể ghép vào calculator/exponential:

- `lcd_init`: khởi tạo LCD.
- `lcd_command`: a0=lệnh; 0x80 đầu dòng 1, 0xC0 đầu dòng 2.
- `lcd_putchar`: a0=mã ASCII.
- `lcd_wait_ready`: chờ controller có thể nhận giao dịch tiếp theo.
- `lcd_delay_cycles`: a0=số chu kỳ cần chờ.

Driver yêu cầu s0=0x40006000, s1=0x40004000 và timer đang bật. Khi tích hợp phải lưu/khôi phục
hoặc đổi các thanh ghi s0/s1 để phù hợp quy ước thanh ghi của app; không ghi đè các thanh ghi
base address mà calculator/exponential đang dùng. Các routine dùng stack và các thanh ghi
caller-saved a0/a1, t0..t2.

Calculator và exponential cũ vẫn chỉ xuất HEX; cần thêm lời gọi driver và chuyển số sang ASCII
nếu muốn đưa kết quả của các app đó lên LCD.

## Phạm vi bản mở rộng

Đây là biến thể có cổng LCD bổ sung cho board. Bản nộp/test TA yêu cầu giữ nguyên cổng top
theo đề thì tiếp tục dùng `../00_src`; không thay trực tiếp bằng biến thể mở rộng này.
Ngoại vi lưu thanh ghi và thực hiện handshake; controller xử lý giao tiếp vật lý LCD,
không có hardware thực hiện chức năng ứng dụng.

Theo yêu cầu của bạn, phiên này chỉ sửa source và assemble demo để tạo `.mem`;
**không chạy test, mô phỏng, compile Quartus hay nạp board**.
