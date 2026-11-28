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
#include "calculator_protocol.h"

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
    char lines[4][17] = {"RV32I Calculator", "Enter in PuTTY", "12 + 34 [Enter]", "q: quit"};
    lcd_lines(lcd, lines);
    return 0;
}
static void lcd_result(struct lcd_display *lcd, const struct calculation *input,
                        const struct calculation_result *result) {
    char lines[4][17] = {{0}};
    snprintf(lines[0], sizeof lines[0], "A:%" PRId32, input->a);
    snprintf(lines[1], sizeof lines[1], "%cB:%" PRId32, input->symbol, input->b);
    if (result->error)
        snprintf(lines[2], sizeof lines[2], "%s",
                 result->error == 1 ? "ERR:DIV BY ZERO" : "ERR:OVERFLOW");
    else
        snprintf(lines[2], sizeof lines[2], "=%" PRId32, result->value);
    if (!result->error && input->operation == 3)
        snprintf(lines[3], sizeof lines[3], "R:%" PRId32, result->remainder);
    else
        snprintf(lines[3], sizeof lines[3], "RV32I / CAL1");
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
        fprintf(stderr, "Cannot lock calculator: another calculator may be running.\n");
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
    if (transfer(&mailbox, CAL_HELLO, &version)) goto cleanup;
    if (version != CAL_VERSION) {
        fprintf(stderr, "Wrong RISC-V firmware (reply 0x%08" PRIx32 ").\n"
                "Compile and load the calculator .sof; the input+1 demo is incompatible.\n", version);
        goto cleanup;
    }
#ifdef WITH_LCD
    struct lcd_display lcd;
    if (lcd_open(&lcd, fd)) goto cleanup;
#endif
    puts("RISC-V full_calculator ready. Enter A op B, then Enter.");
    puts("Signed 32-bit integers; + - * /; example: -12 * 5. Type q to quit.");
    status = 0;
    char buffer[256];
    for (;;) {
        fputs("calc> ", stdout);
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
        struct calculation input;
        if (calculator_parse(line, &input)) {
            puts("Invalid input. Example: -12 / 5. Each operand: -2147483648..2147483647.");
            continue;
        }
        struct calculation_result result;
        int exchange = calculator_run(transfer, &mailbox, &input, &result);
        if (exchange) {
            if (exchange == -2) fputs("Calculator protocol/firmware mismatch.\n", stderr);
            status = 1;
            break;
        }
        if (result.error)
            printf("Error: %s\n", result.error == 1 ? "division by zero" : "signed 32-bit overflow");
        else {
            printf("%" PRId32 " %c %" PRId32 " = %" PRId32,
                   input.a, input.symbol, input.b, result.value);
            if (input.operation == 3) printf(" (remainder %" PRId32 ")", result.remainder);
            putchar('\n');
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
