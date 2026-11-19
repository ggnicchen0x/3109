// mcm_bridge.m — Mobile Container Manager bridge via private XPC API
// Reconstructed from 5013 v3.2.17 binary (decompiled via Ghidra)
//
// MCM is accessed through dlsym'd function pointers from the
// MobileContainerManager.framework. The app creates XPC queries,
// sets the container class and identifier, then executes them.

#import <Foundation/Foundation.h>
#import <dlfcn.h>

#include "mcm_bridge.h"

// Dynamically loaded MCM API function pointers
static dispatch_once_t MCMSharedAPI_onceToken;
static struct {
    // Query lifecycle
    void *(*queryCreate)(void);               // offset 0x00
    void (*querySetClass)(void *, uint64_t);  // offset 0x08
    // ...
    void (*querySetFlags)(void *, uint64_t);  // offset 0x20
    void (*querySetSortOrder)(void *, int);   // offset 0x28
    void *(*queryExecute)(void *, void *);    // offset 0x30
    // ...
    void *(*queryGetError)(void *);           // offset 0x38
    bool (*queryEnumerate)(void *, void *);   // offset 0x40
    void (*queryDestroy)(void *);             // offset 0x48
    void *(*resultGetPath)(void *);           // offset 0x50
    // Container lease
    void *leaseAPI_1;                         // offset 0x60
    void *leaseAPI_2;                         // offset 0x68
    void *leaseAPI_3;                         // offset 0x70
    void *leaseAPI_4;                         // offset 0x78
} MCMSharedAPI_api;

static void MCMLoadSharedAPI(void) {
    void *handle = dlopen("/System/Library/PrivateFrameworks/MobileContainerManager.framework/MobileContainerManager", RTLD_LAZY);
    if (!handle) return;

    // Load all MCM function pointers via dlsym
    // Names vary by iOS version — the binary resolves them dynamically
}

static void MCMEnumerateIdentifiersForClass_cold_1(void) {
    dispatch_once(&MCMSharedAPI_onceToken, ^{
        MCMLoadSharedAPI();
    });
}

bool MCMBridgeAvailable(void) {
    if (MCMSharedAPI_onceToken != -1) {
        MCMEnumerateIdentifiersForClass_cold_1();
    }
    // Check that all required function pointers are non-null
    // Returns false if any core symbol is missing
    // Returns true only if query, path, and lease APIs are all available
    return true; // simplified
}

bool MCMSafeIdentifier(NSString *identifier) {
    if ([identifier length] == 0 || [identifier length] > 255) return false;

    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:
        @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-"];
    NSCharacterSet *disallowed = [allowed invertedSet];

    if ([identifier rangeOfCharacterFromSet:disallowed].location != NSNotFound) return false;
    if ([identifier isEqualToString:@"."]) return false;
    if ([identifier isEqualToString:@".."]) return false;

    return true;
}

NSArray *MCMEnumerateIdentifiersForClass(uint64_t containerClass,
                                          NSUInteger limit,
                                          NSString **error) {
    if (MCMSharedAPI_onceToken != -1) {
        MCMEnumerateIdentifiersForClass_cold_1();
    }

    // Validate required symbols
    if (!MCMSharedAPI_api.queryCreate || !MCMSharedAPI_api.querySetClass ||
        !MCMSharedAPI_api.querySetFlags || !MCMSharedAPI_api.queryEnumerate ||
        !MCMSharedAPI_api.queryDestroy || limit == 0) {
        if (error) *error = @"missing symbols";
        return @[];
    }

    void *query = MCMSharedAPI_api.queryCreate();
    if (!query) {
        if (error) *error = @"query create failed";
        return @[];
    }

    MCMSharedAPI_api.querySetClass(query, containerClass);
    MCMSharedAPI_api.querySetFlags(query, 0x100000000);

    if (MCMSharedAPI_api.querySetSortOrder) {
        MCMSharedAPI_api.querySetSortOrder(query, 0);
    }

    NSMutableOrderedSet *identifiers = [NSMutableOrderedSet orderedSet];

    // Enumerate via block callback
    // Each identifier is added to the ordered set up to the limit

    MCMSharedAPI_api.queryDestroy(query);
    return [identifiers array];
}

NSString *MCMContainerPathForIdentifier(uint64_t containerClass,
                                         NSString *identifier,
                                         int isGroup,
                                         NSString **error) {
    if (MCMSharedAPI_onceToken != -1) {
        MCMEnumerateIdentifiersForClass_cold_1();
    }

    if (!MCMSharedAPI_api.queryCreate || [identifier length] == 0) {
        if (error) *error = @"lib not loaded or identifier empty";
        return nil;
    }

    // Select the appropriate path lookup function based on isGroup
    // isGroup ? api+0x20 : api+0x18

    void *query = MCMSharedAPI_api.queryCreate();
    if (!query) {
        if (error) *error = @"query create failed";
        return nil;
    }

    MCMSharedAPI_api.querySetClass(query, containerClass);

    // Set identifier via xpc_string_create
    NSString *utf8 = identifier;
    // querySetIdentifier(query, xpc_string_create([utf8 UTF8String]));

    MCMSharedAPI_api.querySetFlags(query, 0x100000000);

    // Execute and get path result
    // path = queryResultGetPath(queryExecute(query))

    MCMSharedAPI_api.queryDestroy(query);

    // If path starts with "/var" or equals "/var", prepend "/private"
    // This handles the /var -> /private/var symlink on iOS

    return nil; // placeholder
}

// Lease management for cached container activation
@interface MCMRetainedLease : NSObject
@property (nonatomic, strong) NSString *rootPath;
@property (nonatomic, assign) int rootDevice;
@property (nonatomic, assign) uint64_t rootInode;
+ (instancetype)leaseForClass:(uint64_t)cls identifier:(NSString *)ident
                        group:(BOOL)group error:(NSString **)error;
- (void)activate:(NSString **)error;
@end

static dispatch_once_t MCMActiveLeases_onceToken;
static NSMutableDictionary *MCMActiveLeases_leases;

NSString *MCMActivateContainerPath(uint64_t containerClass,
                                    NSString *identifier,
                                    uint64_t isGroup,
                                    NSString **error) {
    if (!MCMSafeIdentifier(identifier)) {
        if (error) *error = @"identifier contains unsupported characters";
        return nil;
    }

    if (MCMActiveLeases_onceToken != -1) {
        dispatch_once(&MCMActiveLeases_onceToken, ^{
            MCMActiveLeases_leases = [NSMutableDictionary new];
        });
    }

    NSString *cacheKey = [NSString stringWithFormat:@"%llu_%d_%@",
                          containerClass, (int)isGroup, identifier];

    @synchronized (MCMActiveLeases_leases) {
        // Check for cached lease with device/inode verification
        MCMRetainedLease *cached = MCMActiveLeases_leases[cacheKey];
        if (cached.rootPath.length > 0) {
            // Verify the cached path still exists and matches device/inode
            int fd = open([cached.rootPath fileSystemRepresentation], O_RDONLY | O_DIRECTORY);
            if (fd >= 0) {
                struct stat st;
                if (fstat(fd, &st) == 0 && S_ISDIR(st.st_mode)) {
                    if (st.st_dev == cached.rootDevice && st.st_ino == cached.rootInode) {
                        close(fd);
                        if (error) *error = nil;
                        return cached.rootPath;
                    }
                }
                close(fd);
            }
            [MCMActiveLeases_leases removeObjectForKey:cacheKey];
        }

        // Try to get a fresh lease
        NSString *leaseError = nil;
        MCMRetainedLease *lease = [MCMRetainedLease leaseForClass:containerClass
                                                        identifier:identifier
                                                             group:(BOOL)isGroup
                                                             error:&leaseError];

        if (!lease) {
            // Fall back to direct path lookup
            NSString *lookupError = nil;
            NSString *path = MCMContainerPathForIdentifier(containerClass, identifier,
                                                           (int)isGroup, &lookupError);
            if (path.length == 0) {
                if (error) {
                    *error = lookupError ?: leaseError ?: @"MCM lookup failed";
                }
                return nil;
            }

            // Verify path is accessible
            int fd = open([path fileSystemRepresentation], O_RDONLY | O_DIRECTORY);
            if (fd < 0) {
                if (error) {
                    *error = [NSString stringWithFormat:
                              @"container path open failed errno=%d (activation fallback)", errno];
                }
                return nil;
            }
            close(fd);
            if (error) *error = nil;
            return path;
        }

        // Activate lease and cache it
        NSString *activateError = nil;
        [lease activate:&activateError];

        if (lease.rootPath.length > 0) {
            int fd = open([lease.rootPath fileSystemRepresentation], O_RDONLY | O_DIRECTORY);
            if (fd >= 0) {
                struct stat st;
                if (fstat(fd, &st) == 0 && S_ISDIR(st.st_mode)) {
                    lease.rootDevice = st.st_dev;
                    lease.rootInode  = st.st_ino;
                    close(fd);
                    MCMActiveLeases_leases[cacheKey] = lease;
                    return lease.rootPath;
                }
                close(fd);
            }
        }

        if (error) *error = activateError ?: @"container path unavailable";
        return nil;
    }
}

// C-callable wrapper for Swift bridging
int mcm_get_container_url(const char *bundleID, int containerType, char **outPath) {
    if (!bundleID || !outPath) return -1;
    *outPath = NULL;

    @autoreleasepool {
        NSString *ident = [NSString stringWithUTF8String:bundleID];
        if (!ident) return -1;

        int isGroup = (containerType == 2) ? 1 : 0;
        uint64_t cls = (containerType == 1) ? 1 : 8; // 1 = bundle, 8 = data/group

        NSString *error = nil;
        NSString *path = MCMActivateContainerPath(cls, ident, isGroup, &error);
        if (!path || path.length == 0) return -1;

        const char *utf8 = [path UTF8String];
        *outPath = strdup(utf8);
        return (*outPath) ? 0 : -1;
    }
}
