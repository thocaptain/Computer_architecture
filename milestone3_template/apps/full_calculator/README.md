# Full calculator tren DE2 — Milestone 3

Chuong trinh assembly RV32I tinh hai so nguyen co dau 32 bit. Thu tu:

**Nhap A -> xac nhan -> nhap B -> xac nhan -> chon operation -> bat RUN -> xem ket qua.**

Tat RUN de bat dau phep tinh moi. Khong can nap lai FPGA giua cac phep tinh.
Phan mem thuc hien toan bo tinh toan, nhap lieu, chong doi nut va hien thi.

## Tep duoc cung cap

- `full_calculator.s`: ma nguon assembly.
- `full_calculator.mem`: anh IMEM de dung voi `$readmemh`, 1024 dong, moi dong mot lenh 32 bit o dang hex; da dem NOP cho du 4 KiB.
- `full_calculator.elf`, `.bin`, `.dis`: anh lien ket, nhi phan va ban disassembly.
- `build.py`: tao lai cac tep bang GNU RISC-V binutils trong WSL/Linux.
- `test_calculator.py`: chay lenh may RV32I va doi chieu voi ket qua tham chieu.
- `tb_calculator.sv`, `run_rtl_test.py`: kiem tra tren RTL MCU hien tai.
- `board_tb_device.sv`: module thay the cho thiet bi testbench bi thieu trong checkout hien tai. Chi them vao project FPGA neu chua co module `tb_device`; khong them cung mot module khac trung ten.

## Dieu khien

| Thanh phan | Chuc nang |
|---|---|
| SW[3:0] | Chu so thap phan can them, ma nhi phan 0000..1001 (0..9) |
| SW[4] | Dau cua so dang nhap: 0 duong, 1 am |
| SW[6:5] | Operation: 00 cong, 01 tru, 10 nhan, 11 chia |
| SW[16] | Khi nhap A/B: 0 xem 7 chu so cuoi, 1 xem cac chu so dau |
| SW[17] | RUN: bat sau khi chon operation; tat khi xem ket qua de nhap phep moi |
| KEY[0] | Reset MCU, xoa toan bo |
| KEY[1] | Them mot chu so tu SW[3:0] vao ben phai so dang nhap |
| KEY[2] | Xac nhan A, sau do xac nhan B |
| KEY[3] | Khi nhap: xoa chu so cuoi. Khi xem ket qua: trang tiep theo / thuong va so du |

Giu moi nut du lau (khoang 60 ms tro len), sau do tha truoc lan nhan tiep theo.
Giu nut khong lap thao tac. Cac switch khac khong su dung.
Dau duoc chot luc nhan KEY[2], va co the thay doi truoc khi xac nhan.
Neu chua them chu so nao ma nhan KEY[2], so duoc chap nhan la 0.
Khong can giu switch chu so hay dau cua A sau khi da luu A.

**RUN can o OFF truoc khi bat de tinh.** Bat som trong luc nhap A/B se khong tu dong tinh;
hay tat roi bat lai sau khi den buoc chon operation.
Khi RUN dang ON va da co ket qua, thay doi switch khong tinh lai hay thay doi A/B/operation da luu.

## Hien thi

- HEX7 hien dau `-` cho so am; de trong cho so khong am.
- HEX6..HEX0 hien toi da 7 chu so thap phan, can phai.
- Trang 0 la 7 chu so cuoi; trang 1 la cac chu so dau. Khong tu dong cuon.
- Vi du `-2147483648`: trang 0 hien `- 7483648`, trang 1 hien `-     214`.
  Ghép phan dau `214` voi 7 chu so cuoi `7483648` de doc du so.
- Trang dau chi co khi ket qua co tu 8 chu so tro len. Khi nhap lieu, SW16 van cho phep xem trang dau; neu chua co chu so dau thi hien 0.
- Voi phep chia, KEY[3] chuyen: thuong trang 0 -> thuong trang 1 (neu can) -> so du trang 0 -> so du trang 1 (neu can) -> lap lai.
- Voi phep cong/tru/nhan, KEY[3] chuyen giua hai trang neu so dai; so ngan giu nguyen.
- O buoc chon operation, HEX0 hien ma 0, 1, 2 hoac 3 tuong ung cong, tru, nhan, chia.

| LED xanh | Y nghia |
|---|---|
| LEDG[0] | Dang nhap A |
| LEDG[1] | Dang nhap B |
| LEDG[2] | Dang chon operation, cho bat RUN |
| LEDG[3] | Dang hien ket qua |
| LEDG[4] | Dang xem trang 1 (phan chu so dau) |
| LEDG[5] | Dang xem so du cua phep chia |
| LEDG[6] | Gia tri dang hien thi co dau am |
| LEDG[7] | Co loi |

LED do phan anh vi tri cac switch.

## Pham vi va loi

- A, B va ket qua thuoc [-2147483648, 2147483647]. Khong ho tro so thuc.
- Chia lam tron thuong ve 0. So du cung dau voi A (neu khac 0).
  Vi du: -12 / 5 -> thuong -2, so du -2; 12 / -5 -> thuong -2, so du 2.
- `Err1`: chia cho 0.
- `Err2`: ket qua tran so co dau 32 bit; bao gom -2147483648 / -1.
- `Err3`: chu so SW[3:0] nam trong 10..15; khong them chu so do.
- `Err4`: nhap qua 10 chu so, do lon qua 2147483648, hoac xac nhan +2147483648.
  Chu so gay tran khong duoc them. Neu do lon la 2147483648, chon dau am roi xac nhan lai.
- Khi nhap loi, co the xoa bang KEY[3] hoac thuc hien mot thao tac nhap hop le.
  Khi tinh loi, tat RUN de nhap phep moi.

## Vi du -12 x 5

1. Reset, de RUN OFF, SW16 OFF.
2. SW4=1; SW[3:0]=1; nhan/tha KEY1.
3. SW[3:0]=2; nhan/tha KEY1. Man hinh hien -12.
4. Nhan/tha KEY2 de luu A.
5. SW4=0; SW[3:0]=5; nhan/tha KEY1, roi KEY2 de luu B.
6. SW[6:5]=10; bat SW17. Ket qua la -60.
7. Tat SW17 de bat dau phep moi.

## Nap len board

Tep `.mem` la anh chuong trinh cua CPU, khong phai bitstream FPGA `.sof`.
Can dua anh nay vao IMEM, compile Quartus va nap `.sof` len board.

1. Dung MCU trong `milestone3_template/00_src` va `example_de2_wrapper` lam top.
2. Dat tham so `PROGRAMFILE` cua wrapper thanh duong dan den `full_calculator.mem`.
   Cach don gian: copy `.mem` vao thu muc project Quartus, sua gia tri mac dinh cua tham so wrapper thanh:

   ```systemverilog
   parameter PROGRAMFILE = "full_calculator.mem",
   ```

   Quartus phai tim thay tep tu thu muc build; co the dung duong dan tuyet doi voi dau `/`.
3. Giu `IMEM_ADDR_WIDTH=12` (4 KiB) va `DMEM_ADDR_WIDTH=10` (1 KiB) nhu wrapper mac dinh.
   Chuong trinh lien ket tai 0x80000000; du lieu tai 0x84000000; stack bat dau tai 0x84000400 va tang xuong.
   De `DMEM_USE_SRAM` khong duoc dinh nghia cho cau hinh flop DMEM da kiem tra.
4. Khong dinh nghia `SIM_ONLY` khi compile FPGA. `milestone3.sv` se tu buoc cac ngo ra
   debug ve 0 va khong can module TA `tb_device`. `board_tb_device.sv` chi la tep du phong
   cho cac ban MCU cu chua co dieu kien `SIM_ONLY`.
5. Dung pin assignments dung voi mau board DE2 cu the, va SDC cho clock.
6. Giu `CLOCK_DIV_LOG2=1`: CLOCK_50 / 2 = 25 MHz. Hang `SAMPLE_CYCLES=500000`
   trong assembly cho chu ky lay mau 20 ms; can doi hang nay va build lai neu doi tan so CPU.
7. Compile, kiem tra timing, nap `.sof`; reset va thu vi du tren.

Khong dung anh nay voi memory map LSU cu o thu muc `00_src` goc: anh duoc viet cho MCU Milestone 3.
Chua thuc hien Quartus place-and-route hay kiem tra tren board that trong phien nay.

## Build va kiem tra lai (WSL/Linux)

```bash
cd milestone3_template/apps/full_calculator
python3 build.py
python3 test_calculator.py
python3 run_rtl_test.py
```

Can GNU `riscv64-unknown-elf-{as,ld,objcopy,objdump,nm}`. RTL test can Verilator va C++ compiler;
co the dat bien moi truong `VERILATOR` toi executable phu hop.
Ket qua kiem tra RTL duoc ghi vao `rtl_test.log`; thong tin compile vao `rtl_build.log`.
