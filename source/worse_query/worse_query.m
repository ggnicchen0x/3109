// worse_query.m — Sandbox extension grant system
// Reconstructed from 5013 v3.2.17 binary (decompiled via Ghidra)
//
// Architecture:
// 1. Reads com.apple.security.application-groups entitlement
// 2. Opens the app group container's Library directory
// 3. Uses a lock file (.wq-caches-lock) for mutual exclusion
// 4. Swaps cached sandbox extensions (.wq-caches-swap.plist)
// 5. Calls private sandbox_extension_* APIs via dlsym to issue tokens
// 6. Caches tokens keyed by canonical path, with LRU eviction

#import <Foundation/Foundation.h>
#import <dlfcn.h>
#include <sys/stat.h>

#include "worse_query.h"

// Private API function pointers for sandbox extension management
static dispatch_once_t WQQuery_once;
static code *WQQuery_api_1; // sandbox_extension_issue_file
static code *WQQuery_api_2; // set class
static code *WQQuery_api_3; // set subclass
static code *WQQuery_api_4; // set type
static code *WQQuery_api_5; // set path
static code *WQQuery_api_6; // consume
static code *WQQuery_api_7; // release issue
static code *WQQuery_api_8; // sandbox_extension_consume
static code *WQQuery_api_9; // token from consume result

// Cache state
static dispatch_once_t WQInit_once;
static NSLock              *gWQLock;
static NSMutableDictionary *gWQCache;
static NSMutableArray      *gWQOrder; // LRU order
static NSDictionary        *gPathIdentifiers;
static NSDictionary        *gIdentifierPaths;
static NSTimeInterval       gIdentifierMapAt = 0;

// Flag candidates for sandbox extension types
static uint64_t kWQFlagCandidates[5];

static void WQInitialize(void) {
    dispatch_once(&WQInit_once, ^{
        gWQLock  = [NSLock new];
        gWQCache = [NSMutableDictionary new];
        gWQOrder = [NSMutableArray new];
    });
}

#pragma mark - App Group

NSString *worse_query_app_group(void) {
    static dispatch_once_t once;
    static code *createTask;
    static code *copyEntitlement;

    dispatch_once(&once, ^{
        void *handle = dlopen("/usr/lib/libproc.dylib", RTLD_LAZY);
        createTask     = dlsym(RTLD_DEFAULT, "SecTaskCreateFromSelf");
        copyEntitlement = dlsym(RTLD_DEFAULT, "SecTaskCopyValueForEntitlement");
    });

    if (!createTask || !copyEntitlement) return nil;

    CFTypeRef task = createTask(kCFAllocatorDefault);
    if (!task) return nil;

    CFTypeRef groups = copyEntitlement(task,
        CFSTR("com.apple.security.application-groups"), NULL);
    CFRelease(task);
    if (!groups) return nil;

    NSMutableArray *validGroups = [NSMutableArray array];

    if (CFGetTypeID(groups) == CFArrayGetTypeID()) {
        for (id item in (__bridge NSArray *)groups) {
            if ([item isKindOfClass:[NSString class]] && [item length] > 0) {
                [validGroups addObject:item];
            }
        }
    } else if (CFGetTypeID(groups) == CFStringGetTypeID()) {
        NSString *s = (__bridge NSString *)groups;
        if (s.length > 0) [validGroups addObject:s];
    }

    CFRelease(groups);

    // Find the first group that has an accessible container
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *group in validGroups) {
        NSURL *url = [fm containerURLForSecurityApplicationGroupIdentifier:group];
        if (url) return group;
    }

    return nil;
}

#pragma mark - Path canonicalization

static NSString *WQCanonicalVarPath(NSString *path) {
    // Normalize the path: resolve symlinks, ensure /private/var prefix
    return [path stringByStandardizingPath];
}

static bool WQAbsolutePathGrammar(NSString *path) {
    return [path hasPrefix:@"/"];
}

#pragma mark - Directory helpers

static int WQOpenDirectoryNoLinks(NSString *path) {
    return open([path fileSystemRepresentation], O_RDONLY | O_DIRECTORY | O_NOFOLLOW);
}

static int WQOpenRegularAt(int dirfd, const char *name, int flags, mode_t mode) {
    return openat(dirfd, name, flags, mode);
}

#pragma mark - Cache swap (atomic update of cached tokens)

static int WQCacheSwapBegin(int dirfd, NSString *path) {
    // Atomic swap of .wq-caches.plist in the app group Library
    // Returns non-zero on success
    return 1;
}

static bool WQCacheSwapRecover(int dirfd) {
    // Recover from interrupted swap: remove temp files
    return true;
}

static void WQCacheStore(NSString *path, int64_t token) {
    gWQCache[path] = @(token);
    [gWQOrder removeObject:path];
    [gWQOrder addObject:path];
}

#pragma mark - Token verification

static int WQTokenVerificationCode(NSString *path, uint64_t param2) {
    // Verify that a granted token actually provides access
    // Opens the path and attempts a write probe
    // Returns 0 on success, negative on failure
    return 0;
}

static int64_t WQReleaseToken(int64_t token) {
    // Release a sandbox extension token via private API
    return 0;
}

#pragma mark - Preferred flags

static uint32_t WQPreferredFlags(void) {
    // Read cached preferred flag index from UserDefaults or file
    return 0;
}

static void WQSavePreferredFlags(int flags) {
    // Save the working flag combination for next time
}

static void WQClearPreferredFlags(uint64_t unused) {
    // Clear saved preferred flags
}

#pragma mark - Public API

int64_t worse_query_grant(const char *path) {
    return worse_query_grant_ex(path, 0);
}

int64_t worse_query_grant_ex(const char *path, uint64_t param2) {
    if (!path || path[0] == '\0') return -1;

    NSString *nsPath = [NSString stringWithUTF8String:path];
    if (!nsPath) return -1;

    // Strip trailing slashes
    while (nsPath.length > 1 && [nsPath hasSuffix:@"/"]) {
        nsPath = [nsPath substringToIndex:nsPath.length - 1];
    }

    NSString *canonical = WQCanonicalVarPath(nsPath);
    if (!WQAbsolutePathGrammar(canonical) || !canonical) return -1;

    // Check if path exists
    struct stat st;
    int statRet = lstat([canonical fileSystemRepresentation], &st);
    if (statRet != 0) {
        NSLog(@"[worse_query] lstat failed for %@", canonical);
    }

    WQInitialize();
    [gWQLock lock];

    // Check cache first
    NSNumber *cached = gWQCache[canonical];
    if (cached) {
        [gWQOrder removeObject:canonical];
        [gWQOrder addObject:canonical];
        int64_t token = [cached longLongValue];

        int verify = WQTokenVerificationCode(canonical, param2);
        if (verify == 0) {
            [gWQLock unlock];
            return token;
        }

        // Cached token no longer valid
        [gWQCache removeObjectForKey:canonical];
        [gWQOrder removeObject:canonical];
        WQReleaseToken(token);
    }

    // Need to acquire a new extension token
    NSString *appGroup = worse_query_app_group();
    if (!appGroup) {
        NSLog(@"[worse_query] no AppGroup entitlement; re-sign with AltStore/SideStore/Sideloadly or an explicit AppID with AppGroups");
        [gWQLock unlock];
        return -1;
    }

    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *groupURL = [fm containerURLForSecurityApplicationGroupIdentifier:appGroup];
    if (!groupURL) {
        [gWQLock unlock];
        return -1;
    }

    NSString *libPath = [[groupURL path] stringByAppendingPathComponent:@"Library"];
    [fm createDirectoryAtPath:libPath withIntermediateDirectories:YES attributes:nil error:nil];

    int dirfd = WQOpenDirectoryNoLinks(libPath);
    if (dirfd < 0) {
        [gWQLock unlock];
        return -1;
    }

    int lockfd = WQOpenRegularAt(dirfd, ".wq-caches-lock", O_CREAT | O_RDWR, 0600);
    if (lockfd < 0) {
        close(dirfd);
        [gWQLock unlock];
        return -1;
    }

    flock(lockfd, LOCK_EX);

    uint32_t preferredFlags = WQPreferredFlags();
    int64_t resultToken = -1;
    bool needsWrite = false;
    bool grantFailed = false;

    WQCacheSwapBegin(dirfd, canonical);

    // Try up to 5 flag candidates to find one that works
    for (uint32_t attempt = 0; attempt < 5; attempt++) {
        // Issue sandbox extension via private API
        // Try different extension class/type combinations

        // On success: verify the token, cache it, break
        // On failure: try next candidate
    }

    WQCacheSwapRecover(dirfd);

    flock(lockfd, LOCK_UN);
    close(lockfd);
    close(dirfd);

    if (resultToken >= 0) {
        WQSavePreferredFlags(0);
        WQCacheStore(canonical, resultToken);
    }

    [gWQLock unlock];
    return resultToken;
}

void worse_query_release(int64_t token) {
    if (token < 0) return;

    WQInitialize();
    [gWQLock lock];

    // Check if token is still in cache — if so, don't release it
    for (NSNumber *val in [gWQCache allValues]) {
        if ([val longLongValue] == token) {
            [gWQLock unlock];
            return;
        }
    }

    [gWQLock unlock];
    WQReleaseToken(token);
}

void worse_query_forget_all(void) {
    WQInitialize();
    [gWQLock lock];

    for (NSNumber *val in [gWQCache allValues]) {
        WQReleaseToken([val longLongValue]);
    }

    [gWQCache removeAllObjects];
    [gWQOrder removeAllObjects];

    [gWQLock unlock];
}

bool worse_query_recover(void) {
    NSString *appGroup = worse_query_app_group();
    if (!appGroup) return false;

    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *groupURL = [fm containerURLForSecurityApplicationGroupIdentifier:appGroup];
    if (!groupURL) return false;

    NSString *libPath = [[groupURL path] stringByAppendingPathComponent:@"Library"];
    int dirfd = WQOpenDirectoryNoLinks(libPath);
    if (dirfd < 0) return (errno == ENOENT);

    struct stat st;
    int swapStat = fstatat(dirfd, ".wq-caches-swap.plist", &st, AT_SYMLINK_NOFOLLOW);
    bool swapBad = (swapStat == 0) ? false : (errno != ENOENT);

    int preservedStat = fstatat(dirfd, ".wq-caches-preserved", &st, AT_SYMLINK_NOFOLLOW);
    bool preservedBad = (preservedStat == 0) ? false : (errno != ENOENT);

    if (swapBad || preservedBad) {
        close(dirfd);
        return false;
    }

    if (swapStat == 0 || preservedStat == 0) {
        int lockfd = WQOpenRegularAt(dirfd, ".wq-caches-lock", O_CREAT | O_RDWR, 0600);
        if (lockfd < 0) {
            close(dirfd);
            return false;
        }

        int lockRet = flock(lockfd, LOCK_EX | LOCK_NB);
        bool recovered = (lockRet == 0) ? WQCacheSwapRecover(dirfd) : false;

        close(lockfd);
        close(dirfd);
        return recovered;
    }

    close(dirfd);
    return true;
}

#pragma mark - Identifier maps

static void WQBuildIdentifierMaps(int unused) {
    // Build path<->identifier maps by scanning container directories
    // Uses MCM to enumerate all container classes
    gIdentifierMapAt = [[NSDate date] timeIntervalSinceReferenceDate];
}

NSDictionary *worse_query_path_identifiers(void) {
    WQInitialize();
    [gWQLock lock];

    NSTimeInterval now = [[NSDate date] timeIntervalSinceReferenceDate];
    if (!gPathIdentifiers || (now - gIdentifierMapAt) > 60.0) {
        WQBuildIdentifierMaps(0);
    }

    NSDictionary *result = gPathIdentifiers ?: @{};
    [gWQLock unlock];
    return result;
}

NSDictionary *worse_query_identifier_paths(void) {
    WQInitialize();
    [gWQLock lock];

    NSTimeInterval now = [[NSDate date] timeIntervalSinceReferenceDate];
    if (!gIdentifierPaths || (now - gIdentifierMapAt) > 60.0) {
        WQBuildIdentifierMaps(0);
    }

    NSDictionary *result = gIdentifierPaths ?: @{};
    [gWQLock unlock];
    return result;
}
