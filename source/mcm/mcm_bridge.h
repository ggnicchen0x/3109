// mcm_bridge.h — Mobile Container Manager bridge (private API)
// Reconstructed from 5013 v3.2.17 binary

#ifndef MCM_BRIDGE_H
#define MCM_BRIDGE_H

#import <Foundation/Foundation.h>

// Check if the MCM shared API symbols are available
bool MCMBridgeAvailable(void);

// Enumerate container identifiers for a given class
// containerClass: 7 = System, 8 = User, etc.
// limit: max identifiers to return
// error: optional error output
NSArray *MCMEnumerateIdentifiersForClass(uint64_t containerClass,
                                         NSUInteger limit,
                                         NSString **error);

// Get the filesystem path for a container identifier
// containerClass: container class
// identifier: bundle ID or group identifier
// isGroup: 1 for app group containers, 0 for app containers
// error: optional error output
NSString *MCMContainerPathForIdentifier(uint64_t containerClass,
                                         NSString *identifier,
                                         int isGroup,
                                         NSString **error);

// Activate (create/verify) a container path with caching via MCMRetainedLease
NSString *MCMActivateContainerPath(uint64_t containerClass,
                                    NSString *identifier,
                                    uint64_t isGroup,
                                    NSString **error);

// Validate a container identifier (alphanumeric + dots/hyphens, max 255 chars)
bool MCMSafeIdentifier(NSString *identifier);

// C-callable wrapper for Swift bridging
// containerType: 0 = data, 1 = bundle, 2 = group
// outPath: receives malloc'd C string on success (caller must free)
// Returns 0 on success, -1 on failure
int mcm_get_container_url(const char *bundleID, int containerType, char **outPath);

#endif // MCM_BRIDGE_H
