// worse_query.h — Sandbox extension grant system via app group containers
// Reconstructed from 5013 v3.2.17 binary
//
// WQ uses the app's entitlement for security application groups to obtain
// sandbox extension tokens that grant filesystem access to paths outside
// the app's container. Extensions are cached in a plist within the
// app group's Library directory.

#ifndef WORSE_QUERY_H
#define WORSE_QUERY_H

#import <Foundation/Foundation.h>

// Get the first valid app group identifier from entitlements
// Returns the group ID string, or nil if no app groups
NSString *worse_query_app_group(void);

// Grant a sandbox extension for the given path
// Returns the token (>= 0) on success, negative error code on failure
int64_t worse_query_grant(const char *path);

// Grant with extra parameter (group flag)
int64_t worse_query_grant_ex(const char *path, uint64_t param2);

// Release a sandbox extension token
void worse_query_release(int64_t token);

// Release all cached sandbox extension tokens
void worse_query_forget_all(void);

// Recover from interrupted cache swap operations
bool worse_query_recover(void);

// Get current path -> identifier mappings (cached, 60s TTL)
NSDictionary *worse_query_path_identifiers(void);

// Get current identifier -> path mappings (cached, 60s TTL)
NSDictionary *worse_query_identifier_paths(void);

#endif // WORSE_QUERY_H
