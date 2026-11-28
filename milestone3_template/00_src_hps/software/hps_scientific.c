#define _POSIX_C_SOURCE 200809L
#define _FILE_OFFSET_BITS 64
#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>
#include "hps_mailbox.h"
#include "scientific_protocol.h"

static const char *error_text(uint32_t error) {
    return error==1 ? "DIV BY ZERO" : error==2 ? "OVERFLOW" : "ARG RANGE";
}
#ifdef WITH_LCD
#include "lcd/terasic_os_includes.h"
#include "lcd/LCD_Lib.h"
#include "lcd/lcd_graphic.h"
#include "lcd/font.h"
struct lcd_display {
    void *registers;
    LCD_CANVAS canvas;
};
static void lcd_lines(struct lcd_display *lcd, char lines[4][17]) {
    DRAW_Clear(&lcd->canvas, LCD_WHITE);
    for (int row = 0; row < 4; ++row)
        DRAW_PrintString(&lcd->canvas, 0, row * 16, lines[row], LCD_BLACK, &font_16x16);
    DRAW_Refresh(&lcd->canvas);
}
static int lcd_open(struct lcd_display *lcd, int fd) {
    memset(lcd, 0, sizeof *lcd);
    lcd->registers = mmap(NULL, 0x04000000, PROT_READ | PROT_WRITE,
                          MAP_SHARED, fd, ALT_STM_OFST);
    if (lcd->registers == MAP_FAILED) { perror("mmap LCD"); return -1; }
    lcd->canvas.Width = LCD_WIDTH;
    lcd->canvas.Height = LCD_HEIGHT;
    lcd->canvas.BitPerPixel = 1;
    lcd->canvas.FrameSize = LCD_WIDTH * LCD_HEIGHT / 8;
    lcd->canvas.pFrame = calloc(1, lcd->canvas.FrameSize);
    if (!lcd->canvas.pFrame) {
        munmap(lcd->registers, 0x04000000);
        return -1;
    }
    LCDHW_Init(lcd->registers);
    LCDHW_BackLight(true);
    LCD_Init();
    char lines[4][17] = {"RV32I Scientific", "12 + 34; -17 / 5", "exp / sin / cos", "DEG; q: quit"};
    lcd_lines(lcd, lines);
    return 0;
}
static void lcd_result(struct lcd_display *lcd, const struct scientific_input *input,
                       const struct scientific_result *result) {
    char lines[4][17] = {{0}};
    char value[17];
    if (input->operation>=3) {
        snprintf(lines[0],sizeof lines[0],"A:%" PRId32,input->argument);
        snprintf(lines[1],sizeof lines[1],"%s %" PRId32,scientific_name(input->operation),input->operand_b);
        if (result->error) snprintf(lines[2],sizeof lines[2],"ERR:%s",error_text(result->error));
        else snprintf(lines[2],sizeof lines[2],"=%" PRId32,result->value);
        if (!result->error && input->operation==6)
            snprintf(lines[3],sizeof lines[3],"REM:%" PRId32,result->remainder);
        else snprintf(lines[3],sizeof lines[3],"RV32I / SCI2");
    } else {
        snprintf(lines[0],sizeof lines[0],"%s(x)%s",scientific_name(input->operation),input->operation ? " DEG" : "");
        scientific_format(value,sizeof value,input->argument);
        snprintf(lines[1],sizeof lines[1],"x:%.14s",value);
        if (result->error) snprintf(lines[2],sizeof lines[2],"ERR:%s",error_text(result->error));
        else {
            scientific_format(value,sizeof value,result->value);
            snprintf(lines[2],sizeof lines[2],"=%.15s",value);
        }
        snprintf(lines[3],sizeof lines[3],"RV32I / SCI2");
    }
    lcd_lines(lcd, lines);
}
static void lcd_close(struct lcd_display *lcd) {
    free(lcd->canvas.pFrame);
    munmap(lcd->registers, 0x04000000);
}
#endif

struct mailbox {
    volatile uint32_t *registers;
};
static uint32_t read_register(struct mailbox *mailbox, unsigned offset) {
    uint32_t value = mailbox->registers[offset / 4];
    __sync_synchronize();
    return value;
}
static void write_register(struct mailbox *mailbox, unsigned offset, uint32_t value) {
    __sync_synchronize();
    mailbox->registers[offset / 4] = value;
    __sync_synchronize();
}
static double seconds(void) {
    struct timespec now;
    if (clock_gettime(CLOCK_MONOTONIC, &now)) { perror("clock_gettime"); exit(1); }
    return now.tv_sec + now.tv_nsec / 1e9;
}
static int transfer(void *context, uint32_t command, uint32_t *response) {
    struct mailbox *mailbox = context;
    if (read_register(mailbox, MB_STATUS) & (MB_CMD_VALID | MB_RSP_VALID)) {
        fprintf(stderr, "Mailbox busy. Stop other clients; KEY[0] resets an abandoned transaction.\n");
        return -1;
    }
    write_register(mailbox, MB_COMMAND, command);
    write_register(mailbox, MB_CONTROL, MB_START);
    double deadline = seconds() + 2.0;
    while (!(read_register(mailbox, MB_STATUS) & MB_RSP_VALID)) {
        if (seconds() > deadline) {
            fprintf(stderr, "RISC-V response timeout. Check CPU clock/reset/firmware.\n");
            return -1;
        }
        struct timespec delay = {0, 1000000};
        nanosleep(&delay, NULL);
    }
    *response = read_register(mailbox, MB_RESPONSE);
    write_register(mailbox, MB_CONTROL, MB_ACK);
    return 0;
}
static int physical_address(const char *text, uint64_t *address) {
    char *end;
    errno = 0;
    unsigned long long value = strtoull(text, &end, 0);
    if (errno || text[0] == '-' || end == text || *end ||
        value > UINT32_MAX - 31u || (value & 31u)) return -1;
    *address = value;
    return 0;
}
static char *trim(char *text) {
    while (isspace((unsigned char)*text)) ++text;
    size_t length = strlen(text);
    while (length && isspace((unsigned char)text[length - 1])) text[--length] = 0;
    return text;
}
int main(int argc, char **argv) {
    uint64_t address;
    if (argc != 2 || physical_address(argv[1], &address)) {
        fprintf(stderr, "Usage: %s PHYSICAL_MAILBOX_ADDRESS\nExample: %s 0xff206000\n", argv[0], argv[0]);
        return 2;
    }
    int lock = open("/tmp/hps_calculator.lock", O_RDWR | O_CREAT, 0600);
    if (lock < 0 || flock(lock, LOCK_EX | LOCK_NB)) {
        fprintf(stderr, "Cannot lock scientific: another mailbox application may be running.\n");
        if (lock >= 0) close(lock);
        return 1;
    }
    long page_size = sysconf(_SC_PAGESIZE);
    if (page_size <= 0) { close(lock); return 1; }
    uint64_t base = address & ~((uint64_t)page_size - 1);
    int fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd < 0) { perror("open /dev/mem"); close(lock); return 1; }
    void *mapping = mmap(NULL, page_size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, (off_t)base);
    if (mapping == MAP_FAILED) { perror("mmap mailbox"); close(fd); close(lock); return 1; }
    struct mailbox mailbox = {(volatile uint32_t *)((uint8_t *)mapping + address - base)};
    int status = 1;
    if (read_register(&mailbox, MB_ID) != MB_SIGNATURE) {
        fprintf(stderr, "Mailbox ID mismatch; verify .sof and address map.\n");
        goto cleanup;
    }
    uint32_t version;
    if (transfer(&mailbox, SCI_HELLO, &version)) goto cleanup;
    if (version != SCI_VERSION) {
        fprintf(stderr, "Wrong RISC-V firmware (reply 0x%08" PRIx32 ").\n"
                "Compile and load the scientific .sof; calculator and input+1 firmware are incompatible.\n", version);
        goto cleanup;
    }
#ifdef WITH_LCD
    struct lcd_display lcd;
    if (lcd_open(&lcd, fd)) goto cleanup;
#endif
    puts("RISC-V scientific ready. Enter A + B, A - B, A * B, A / B, exp X, sin DEG or cos DEG.");
    puts("Arithmetic: signed 32-bit integers. Scientific: up to 3 decimal places. exp: [-9,9]; trig: [-360000,360000] degrees. q: quit.");
    status = 0;
    char buffer[256];
    for (;;) {
        fputs("math> ", stdout);
        fflush(stdout);
        if (!fgets(buffer, sizeof buffer, stdin)) break;
        if (!strchr(buffer, '\n') && !feof(stdin)) {
            int ch;
            while ((ch = getchar()) != '\n' && ch != EOF) {}
            puts("Input too long; enter one expression per line.");
            continue;
        }
        char *line = trim(buffer);
        if (!*line) continue;
        if (!strcmp(line, "q") || !strcmp(line, "quit") || !strcmp(line, "exit")) break;
        struct scientific_input input;
        if (scientific_parse(line, &input)) {
            puts("Invalid input/range. Use 12 + 34, -17 / 5, exp 1.5, sin 30 or cos 60.");
            continue;
        }
        struct scientific_result result;
        int exchange = scientific_run(transfer, &mailbox, &input, &result);
        if (exchange) {
            if (exchange == -2) fputs("Scientific protocol/firmware mismatch.\n", stderr);
            status = 1;
            break;
        }
        if (result.error)
            printf("Error: %s\n", error_text(result.error));
        else if (input.operation>=3) {
            printf("%" PRId32 " %s %" PRId32 " = %" PRId32,input.argument,
                   scientific_name(input.operation),input.operand_b,result.value);
            if (input.operation==6) printf(" (remainder %" PRId32 ")",result.remainder);
            putchar('\n');
        } else {
            char argument[17], value[17];
            scientific_format(argument, sizeof argument, input.argument);
            scientific_format(value, sizeof value, result.value);
            printf("%s(%s%s) = %s\n", scientific_name(input.operation), argument,
                   input.operation ? " deg" : "", value);
        }
#ifdef WITH_LCD
        lcd_result(&lcd, &input, &result);
#endif
    }
    if (ferror(stdin)) { perror("stdin"); status = 1; }
#ifdef WITH_LCD
    lcd_close(&lcd);
#endif
cleanup:
    munmap(mapping, page_size);
    close(fd);
    close(lock);
    return status;
}
