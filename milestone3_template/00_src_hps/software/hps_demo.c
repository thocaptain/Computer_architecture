#define _POSIX_C_SOURCE 200809L
#define _FILE_OFFSET_BITS 64
#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>
#include "hps_mailbox.h"
#ifdef WITH_LCD
#include "lcd/terasic_os_includes.h"
#include "lcd/LCD_Lib.h"
#include "lcd/lcd_graphic.h"
#include "lcd/font.h"

static int display_result(int fd, uint32_t value) {
    const size_t span = 0x04000000;
    void *base = mmap(NULL, span, PROT_READ | PROT_WRITE, MAP_SHARED, fd, ALT_STM_OFST);
    if (base == MAP_FAILED) { perror("mmap LCD registers"); return -1; }
    LCD_CANVAS canvas = {0};
    canvas.Width = LCD_WIDTH;
    canvas.Height = LCD_HEIGHT;
    canvas.BitPerPixel = 1;
    canvas.FrameSize = canvas.Width * canvas.Height / 8;
    canvas.pFrame = calloc(1, canvas.FrameSize);
    if (!canvas.pFrame) { munmap(base, span); return -1; }
    char output[32];
    snprintf(output, sizeof output, "%08" PRIX32, value);
    LCDHW_Init(base);
    LCDHW_BackLight(true);
    LCD_Init();
    DRAW_Clear(&canvas, LCD_WHITE);
    DRAW_PrintString(&canvas, 0, 0, "RV32I", LCD_BLACK, &font_16x16);
    DRAW_PrintString(&canvas, 0, 20, output, LCD_BLACK, &font_16x16);
    DRAW_PrintString(&canvas, 0, 40, "HEX", LCD_BLACK, &font_16x16);
    DRAW_Refresh(&canvas);
    free(canvas.pFrame);
    munmap(base, span);
    return 0;
}
#endif

static uint32_t read_reg(volatile uint32_t *regs, unsigned offset) {
    uint32_t value = regs[offset / 4];
    __sync_synchronize();
    return value;
}
static void write_reg(volatile uint32_t *regs, unsigned offset, uint32_t value) {
    __sync_synchronize();
    regs[offset / 4] = value;
    __sync_synchronize();
}
static double seconds(void) {
    struct timespec now;
    if (clock_gettime(CLOCK_MONOTONIC, &now)) { perror("clock_gettime"); exit(1); }
    return now.tv_sec + now.tv_nsec / 1e9;
}
static unsigned long long number(const char *text, unsigned long long limit) {
    char *end;
    errno = 0;
    unsigned long long value = strtoull(text, &end, 0);
    if (errno || text[0] == '-' || end == text || *end || value > limit) {
        fprintf(stderr, "Invalid numeric argument: %s\n", text);
        exit(2);
    }
    return value;
}
int main(int argc, char **argv) {
    if (argc != 3) {
        fprintf(stderr, "Usage: %s PHYSICAL_MAILBOX_ADDRESS UINT32\n", argv[0]);
        return 2;
    }
    uint64_t address = number(argv[1], UINT32_MAX - 31u);
    uint32_t command = (uint32_t)number(argv[2], UINT32_MAX);
    long page_size = sysconf(_SC_PAGESIZE);
    if (page_size <= 0 || (address & 31u)) {
        fprintf(stderr, "Mailbox physical address must be 32-byte aligned\n"); return 2;
    }
    uint64_t aligned = address & ~((uint64_t)page_size - 1u);
    size_t offset = (size_t)(address - aligned);
    int fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd < 0) { perror("open /dev/mem"); return 1; }
    void *mapped = mmap(NULL, (size_t)page_size, PROT_READ | PROT_WRITE,
                        MAP_SHARED, fd, (off_t)aligned);
    if (mapped == MAP_FAILED) { perror("mmap mailbox"); close(fd); return 1; }
    volatile uint32_t *regs = (volatile uint32_t *)((uint8_t *)mapped + offset);
    int status = 1;
    if (read_reg(regs, MB_ID) != MB_SIGNATURE) {
        fprintf(stderr, "Mailbox ID mismatch: check bitstream and physical address\n");
        goto cleanup;
    }
    if (read_reg(regs, MB_STATUS) & (MB_CMD_VALID | MB_RSP_VALID)) {
        fprintf(stderr, "Mailbox busy or unacknowledged result; use one host process\n");
        goto cleanup;
    }
    write_reg(regs, MB_COMMAND, command);
    write_reg(regs, MB_CONTROL, MB_START);
    double deadline = seconds() + 2.0;
    while (!(read_reg(regs, MB_STATUS) & MB_RSP_VALID)) {
        if (seconds() > deadline) {
            fprintf(stderr, "CPU response timeout; command remains pending\n"); goto cleanup;
        }
        struct timespec delay = {0, 1000000};
        nanosleep(&delay, NULL);
    }
    uint32_t result = read_reg(regs, MB_RESPONSE);
    write_reg(regs, MB_CONTROL, MB_ACK);
    printf("HPS sent %" PRIu32 "; RV32I returned %" PRIu32 "\n", command, result);
    status = 0;
#ifdef WITH_LCD
    if (display_result(fd, result)) status = 1;
#endif
cleanup:
    munmap(mapped, (size_t)page_size);
    close(fd);
    return status;
}
