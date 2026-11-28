# Exponential — e^x trên DE2 Cyclone II

Ứng dụng thuộc mục Exponential của Milestone 3: tính e mũ x, hiển thị 3 chữ số thập phân.
Toàn bộ phép tính, nhập liệu, chống dội nút và hiển thị nằm trong assembly RV32I.

## Phạm vi và biểu diễn

- Nhập x từ **−9,000 đến +9,000**, theo bước **0,001**.
- Nhập số dưới dạng **x nhân 1000**, tối đa 4 chữ số. Ví dụ:

| x mong muốn | Các chữ số cần nhập | SW4 |
|---|---|---|
| 0,001 | 1 | OFF |
| 0,500 | 5, 0, 0 | OFF |
| 1,000 | 1, 0, 0, 0 | OFF |
| 1,500 | 1, 5, 0, 0 | OFF |
| −2,000 | 2, 0, 0, 0 | ON |
| 9,000 | 9, 0, 0, 0 | OFF |

- Không có nút nhập dấu phẩy; vị trí dấu phẩy luôn cố định trước 3 chữ số cuối.
- Kết quả là số nguyên gần nhất của `1000 * exp(x)`, rồi hiển thị 3 chữ số lẻ.
- Giá trị rất nhỏ có thể hiển thị `0-000` sau khi làm tròn, ví dụ x=−9,000.
- Phạm vi này giữ phần nguyên kết quả tối đa 4 chữ số (e^9 xấp xỉ 8103,084).

## Điều khiển

| Thành phần | Chức năng |
|---|---|
| SW[3:0] | Chọn chữ số 0–9 bằng mã nhị phân |
| SW[4] | Dấu của x: OFF dương, ON âm |
| KEY[1] | Thêm chữ số đang chọn vào bên phải số nhập |
| KEY[2] | Xác nhận x, chuyển sang chờ RUN |
| KEY[3] | Xóa chữ số cuối khi đang nhập |
| SW[17] | Bật sau khi xác nhận để tính; tắt khi có kết quả để nhập mới |
| KEY[0] | Reset toàn bộ |

Các switch còn lại không dùng trong app này. Nhấn rồi thả từng nút; giữ mỗi trạng thái
khoảng 60 ms trở lên. Giữ nút không lặp thao tác. Muốn sửa x sau khi đã xác nhận, dùng reset.
Nếu RUN đã bật trước khi xác nhận, tắt rồi bật lại khi đến trạng thái chờ RUN.

## HEX và LED trạng thái

Wrapper chỉ có 7 đoạn mỗi HEX, không có chân chấm thập phân. Vì vậy **HEX3 dùng gạch ngang
làm dấu ngăn thập phân**. Đây là ký hiệu hiển thị, không phải phép trừ.

```text
HEX7 HEX6 HEX5 HEX4 HEX3 HEX2 HEX1 HEX0
                   2    -    7    1    8    => 2,718
   8    1    0    3    -    0    8    4    => 8103,084
   -              1    -    5    0    0    => x = −1,500 khi nhập
```

- HEX7–HEX4: phần nguyên, căn phải.
- HEX3: dấu ngăn thập phân `-`.
- HEX2–HEX0: đúng 3 chữ số lẻ, có thêm số 0 ở đầu nếu cần.
- Khi nhập x âm, HEX7 hiển thị dấu âm. x chỉ có một chữ số phần nguyên nên không đè lên dấu.
- Kết quả e^x luôn không âm; không hiển thị dấu âm ở chế độ kết quả.

| LED | Ý nghĩa |
|---|---|
| LEDG0 | Đang nhập x |
| LEDG1 | Đã lưu x, chờ bật RUN |
| LEDG2 | Đang hiển thị kết quả |
| LEDG3 | Đang tính (có thể sáng rất ngắn) |
| LEDG5 | Định dạng cố định 3 chữ số thập phân |
| LEDG6 | x đang hiển thị là số âm |
| LEDG7 | Lỗi nhập |

LED đỏ phản ánh trạng thái switch. `Err3`: SW[3:0] là 10..15. `Err4`: nhập quá 4 chữ số
hoặc độ lớn quá 9000. Chữ số gây lỗi không được thêm. Xóa hoặc nhập hợp lệ để bỏ lỗi.

## Ví dụ e^1 = 2,718…

1. Để SW17 OFF, SW4 OFF; nhấn/thả KEY0.
2. Chọn SW[3:0]=0001, nhấn/thả KEY1.
3. Chọn SW[3:0]=0000, nhấn/thả KEY1 **ba lần**. Màn hình hiện `1-000`.
4. Nhấn/thả KEY2: LEDG1 sáng.
5. Bật SW17: màn hình kết quả dự kiến là `2-718`, LEDG2 sáng.
6. Tắt SW17 để bắt đầu lượt mới.

Các giá trị tham chiếu toán học khác: e^0 → `1-000`, e^(−1) → `0-368`,
e^2 → `7-389`, e^1,5 → `4-482`, e^9 → `8103-084`.
Đây là giá trị tham chiếu, không phải kết quả kiểm thử của phiên tạo app.

## Cách tính bằng RV32I

Hàm `exp_milli` nhận a0 là x nhân 1000 và trả a0 là kết quả nhân 1000, a1 là mã lỗi.
Đầu tiên chuyển x sang fixed point Q32 bằng phép chia 64 bit. Giảm miền:

```text
x = n * ln(2) + r, với 0 <= r < ln(2)
exp(x) = 2^n * exp(r)
exp(r) ≈ 1 + r + r²/2! + … + r¹⁸/18!
```

Hằng ln(2) dùng `round(ln(2)*2^32) = 0xB17217F8`. Các số hạng và tổng được giữ ở Q48;
phép nhân trung gian dùng tối đa 96 bit. Sau đó nhân 1000, dịch theo n và làm tròn về số
nguyên gần nhất. Các phép nhân/chia đều là routine phần mềm bằng dịch, cộng và trừ;
không dùng lệnh MUL/DIV hay dấu phẩy động. Đây là phép xấp xỉ số học, không phải bảng tra e^x.

## Chọn app để nạp FPGA

File `.mem` riêng nằm tại:

```text
//wsl.localhost/Ubuntu-20.04/home/lqhau/RISC-V-RV32i-master/milestone3_template/apps/exponential/exponential.mem
```

Calculator hiện vẫn là chương trình mặc định. Để chuyển sang Exponential, thay dòng
`IMEM_FILE` trong `milestone3_template/00_src/mcu_config.svh` bằng:

```systemverilog
`define IMEM_FILE {"/", "/wsl.localhost/Ubuntu-20.04/home/lqhau/RISC-V-RV32i-master/milestone3_template/apps/exponential/exponential.mem"}
```

Giữ cấu hình board như calculator: top `example_de2_wrapper`, IMEM 4 KiB, DMEM 1 KiB,
clock MCU 25 MHz (`CLOCK_DIV_LOG2=1`), cùng pin assignment và SDC. Đây là app riêng;
không có menu chọn calculator/exponential trong cùng ảnh chương trình.
Sau khi đổi ảnh IMEM, compile lại Quartus và nạp `.sof` mới.

## Tạo lại .mem

```bash
cd milestone3_template/apps/exponential
python3 build.py
```

Script dùng GNU RISC-V binutils, tạo `.elf`, `.bin`, `.dis` và `.mem` 1024 word.
Entry là 0x80000000. DMEM bắt đầu ở 0x84000000, stack ở 0x84000400 và tăng xuống.
Bảng mã LED được khởi tạo trong DMEM vì bus dữ liệu không đọc IMEM.

**Theo yêu cầu chỉ viết chương trình, phiên này không chạy test, mô phỏng hay compile Quartus.**
Việc assemble/link chỉ nhằm tạo ảnh `.mem`; kết quả chưa được xác nhận trên board.
