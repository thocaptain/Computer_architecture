#ifndef HPS_MAILBOX_H
#define HPS_MAILBOX_H
#define MB_ID         0x00u
#define MB_STATUS     0x04u
#define MB_COMMAND    0x08u
#define MB_RESPONSE   0x0cu
#define MB_CONTROL    0x10u
#define MB_IRQ_ENABLE 0x14u
#define MB_SIGNATURE  0x48505331u
#define MB_CMD_VALID  1u
#define MB_RSP_VALID  2u
#define MB_START      1u
#define MB_ACK        2u
#endif
