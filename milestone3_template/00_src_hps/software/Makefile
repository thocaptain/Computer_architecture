CROSS_COMPILE ?= arm-linux-gnueabihf-
CC = $(CROSS_COMPILE)gcc
CFLAGS = -O2 -Wall -Wextra -std=gnu99
LDFLAGS ?= -static
SOCEDS_ROOT ?= $(SOCEDS_DEST_ROOT)
HWLIBS_ROOT = $(SOCEDS_ROOT)/ip/altera/hps/altera_hps/hwlib
LCD_SOURCES = lcd/terasic_lib.c lcd/LCD_Lib.c lcd/LCD_Driver.c lcd/LCD_Hw.c lcd/lcd_graphic.c lcd/font.c

.PHONY: all clean
all: hps_demo hps_calculator
hps_demo: hps_demo.c hps_mailbox.h
	$(CC) $(CFLAGS) $(LDFLAGS) hps_demo.c -o $@ -lrt
hps_demo_lcd: hps_demo.c hps_mailbox.h $(LCD_SOURCES)
	$(CC) $(CFLAGS) $(LDFLAGS) -DWITH_LCD -Dsoc_cv_av -Ilcd -I$(HWLIBS_ROOT)/include -I$(HWLIBS_ROOT)/include/soc_cv_av hps_demo.c $(LCD_SOURCES) -o $@ -lrt -lm
hps_calculator: hps_calculator.c calculator_protocol.c calculator_protocol.h hps_mailbox.h
	$(CC) $(CFLAGS) $(LDFLAGS) hps_calculator.c calculator_protocol.c -o $@ -lrt
hps_calculator_lcd: hps_calculator.c calculator_protocol.c calculator_protocol.h hps_mailbox.h $(LCD_SOURCES)
	$(CC) $(CFLAGS) $(LDFLAGS) -DWITH_LCD -Dsoc_cv_av -Ilcd -I$(HWLIBS_ROOT)/include -I$(HWLIBS_ROOT)/include/soc_cv_av hps_calculator.c calculator_protocol.c $(LCD_SOURCES) -o $@ -lrt -lm
hps_scientific: hps_scientific.c scientific_protocol.c scientific_protocol.h hps_mailbox.h
	$(CC) $(CFLAGS) $(LDFLAGS) hps_scientific.c scientific_protocol.c -o $@ -lrt
hps_scientific_lcd: hps_scientific.c scientific_protocol.c scientific_protocol.h hps_mailbox.h $(LCD_SOURCES)
	$(CC) $(CFLAGS) $(LDFLAGS) -DWITH_LCD -Dsoc_cv_av -Ilcd -I$(HWLIBS_ROOT)/include -I$(HWLIBS_ROOT)/include/soc_cv_av hps_scientific.c scientific_protocol.c $(LCD_SOURCES) -o $@ -lrt -lm
clean:
	rm -f hps_demo hps_demo_lcd hps_calculator hps_calculator_lcd hps_scientific hps_scientific_lcd
