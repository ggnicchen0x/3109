// app_info.m — Installed app enumeration via MobileInstallation + LSApplicationWorkspace
// Reconstructed from 5013 v3.2.17 binary (decompiled via Ghidra)
//
// Two sources are merged:
// 1. MobileInstallation private API (dlsym'd MobileInstallationLookup)
//    - Queries multiple lookup types to build a dict of bundleID -> app info
// 2. LSApplicationWorkspace (runtime class lookup)
//    - Enumerates app proxies via multiple selector names
//    - Extracts bundleID, display name, container path, version
// Results from both are merged, with LS data taking priority for missing fields.

#import <Foundation/Foundation.h>
#import <dlfcn.h>

#include "app_info.h"

// Helper: given a dict and an array of key candidates, return first non-empty string value
static NSString *stringForFirstKey(NSDictionary *dict, NSArray *keys) {
    for (NSString *key in keys) {
        id val = dict[key];
        if ([val isKindOfClass:[NSString class]] && [val length] > 0) {
            return val;
        }
    }
    return nil;
}

#pragma mark - MobileInstallation

static dispatch_once_t mobileInstallationHandle_onceToken;
static void *mobileInstallationHandle_handle;

static void loadMobileInstallation(void) {
    dispatch_once(&mobileInstallationHandle_onceToken, ^{
        mobileInstallationHandle_handle =
            dlopen("/System/Library/PrivateFrameworks/MobileInstallation.framework/MobileInstallation",
                   RTLD_LAZY);
    });
}

#pragma mark - LSApplicationWorkspace

static dispatch_once_t ensureLaunchServicesLoaded_onceToken;

static void loadLaunchServices(void) {
    dispatch_once(&ensureLaunchServicesLoaded_onceToken, ^{
        dlopen("/System/Library/Frameworks/CoreServices.framework/CoreServices", RTLD_LAZY);
    });
}

#pragma mark - installedAppInfo

NSDictionary *installedAppInfo(void) {
    NSMutableDictionary *miResults = [NSMutableDictionary dictionary];

    // Phase 1: MobileInstallation
    loadMobileInstallation();

    typedef NSDictionary *(*MILookupFunc)(NSDictionary *options, ...);
    MILookupFunc miLookup = dlsym(RTLD_DEFAULT, "MobileInstallationLookup");
    if (!miLookup && mobileInstallationHandle_handle) {
        miLookup = dlsym(mobileInstallationHandle_handle, "MobileInstallationLookup");
    }

    if (miLookup) {
        // Lookup type keys to query
        NSArray *lookupTypes = @[
            @"User",
            @"System",
            @"Internal"
        ];

        for (NSString *type in lookupTypes) {
            NSDictionary *result = miLookup(@{@"ReturnAttributes": @[@"BundleIdentifier",
                                                                      @"CFBundleDisplayName",
                                                                      @"CFBundleName",
                                                                      @"Path",
                                                                      @"Container",
                                                                      @"CFBundleShortVersionString"],
                                               @"ApplicationType": type}, nil);
            if (![result isKindOfClass:[NSDictionary class]] || result.count == 0) continue;

            for (NSString *bundleID in result) {
                if (miResults[bundleID]) continue;

                @autoreleasepool {
                    NSDictionary *info = result[bundleID];
                    if (![info isKindOfClass:[NSDictionary class]]) continue;

                    NSString *name = stringForFirstKey(info, @[@"CFBundleDisplayName",
                                                                @"CFBundleName"]);
                    if (!name.length) name = bundleID;
                    if (!name.length) continue;

                    NSString *displayName = stringForFirstKey(info, @[@"CFBundleDisplayName"]);

                    // Container path: try URL first, then string
                    NSString *container = nil;
                    NSArray *containerKeys = @[@"Container", @"Path"];
                    for (NSString *key in containerKeys) {
                        id val = info[key];
                        if ([val isKindOfClass:[NSURL class]]) {
                            container = [val path];
                        } else if ([val isKindOfClass:[NSString class]]) {
                            container = val;
                        }
                        if (container.length) break;
                    }

                    NSString *version = stringForFirstKey(info, @[@"CFBundleShortVersionString"]);

                    NSMutableDictionary *entry = [NSMutableDictionary dictionary];
                    NSString *finalName = displayName.length ? displayName : name;
                    entry[@"name"] = finalName;
                    if (container.length) entry[@"container"] = container;
                    if (version.length) entry[@"version"] = version;

                    miResults[name] = entry;
                }
            }
        }
    }

    // Phase 2: LSApplicationWorkspace
    NSMutableDictionary *lsResults = [NSMutableDictionary dictionary];

    loadLaunchServices();

    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    if (!workspaceClass) {
        NSLog(@"[5013:ls] LSApplicationWorkspace class unavailable");
        goto merge;
    }

    SEL defaultWSSel = NSSelectorFromString(@"defaultWorkspace");
    if (![workspaceClass respondsToSelector:defaultWSSel]) {
        NSLog(@"[5013:ls] defaultWorkspace selector unavailable");
        goto merge;
    }

    {
        id workspace = ((id (*)(id, SEL))objc_msgSend)(workspaceClass, defaultWSSel);
        if (!workspace) {
            NSLog(@"[5013:ls] defaultWorkspace returned nil");
            goto merge;
        }

        // Try multiple selectors to get app proxies
        NSMutableArray *allProxies = [NSMutableArray array];
        NSMutableArray *sourceSummary = [NSMutableArray array];

        NSArray *proxySelectors = @[
            @"allInstalledApplications",
            @"allApplications",
            @"applicationsOfType:"
        ];

        for (NSString *selName in proxySelectors) {
            SEL sel = NSSelectorFromString(selName);
            if (![workspace respondsToSelector:sel]) continue;

            NSArray *proxies = ((id (*)(id, SEL))objc_msgSend)(workspace, sel);
            if ([proxies isKindOfClass:[NSArray class]] && proxies.count > 0) {
                [allProxies addObjectsFromArray:proxies];
                [sourceSummary addObject:[NSString stringWithFormat:@"%@=%lu",
                                          selName, (unsigned long)proxies.count]];
            } else {
                NSLog(@"[5013:ls] %@ returned %lu", selName,
                      (unsigned long)([proxies isKindOfClass:[NSArray class]] ? proxies.count : 0));
            }
        }

        if (allProxies.count == 0) {
            NSLog(@"[5013:ls] workspace enumeration empty");
            goto merge;
        }

        NSLog(@"[5013:ls] workspace proxies: %@ total: %lu",
              [sourceSummary componentsJoinedByString:@", "],
              (unsigned long)allProxies.count);

        for (id proxy in allProxies) {
            @autoreleasepool {
                // Extract bundle identifier
                NSString *bundleID = nil;
                NSArray *idSelectors = @[@"applicationIdentifier", @"bundleIdentifier"];
                for (NSString *selName in idSelectors) {
                    SEL sel = NSSelectorFromString(selName);
                    if ([proxy respondsToSelector:sel]) {
                        id val = ((id (*)(id, SEL))objc_msgSend)(proxy, sel);
                        if ([val isKindOfClass:[NSString class]] && [val length] > 0) {
                            bundleID = val;
                            break;
                        }
                    }
                }
                if (!bundleID.length) continue;

                // Extract display name
                NSString *displayName = nil;
                NSArray *nameSelectors = @[@"localizedName", @"localizedShortName", @"itemName"];
                for (NSString *selName in nameSelectors) {
                    SEL sel = NSSelectorFromString(selName);
                    if ([proxy respondsToSelector:sel]) {
                        id val = ((id (*)(id, SEL))objc_msgSend)(proxy, sel);
                        if ([val isKindOfClass:[NSString class]] && [val length] > 0) {
                            displayName = val;
                            break;
                        }
                    }
                }
                if (!displayName.length) displayName = bundleID;

                NSMutableDictionary *entry = [NSMutableDictionary dictionary];
                entry[@"name"] = displayName;

                // Extract container path
                NSArray *containerSelectors = @[@"dataContainerURL", @"bundleContainerURL", @"bundleURL"];
                for (NSString *selName in containerSelectors) {
                    SEL sel = NSSelectorFromString(selName);
                    if ([proxy respondsToSelector:sel]) {
                        id val = ((id (*)(id, SEL))objc_msgSend)(proxy, sel);
                        NSString *path = nil;
                        if ([val isKindOfClass:[NSURL class]]) {
                            path = [val path];
                        } else if ([val isKindOfClass:[NSString class]]) {
                            path = val;
                        }
                        if (path.length) {
                            entry[@"container"] = path;
                            break;
                        }
                    }
                }

                if (!lsResults[bundleID]) {
                    lsResults[bundleID] = entry;
                }
            }
        }

        NSLog(@"[5013:ls] extracted %lu apps (%lu with container)",
              (unsigned long)lsResults.count,
              (unsigned long)[[lsResults allValues] filteredArrayUsingPredicate:
                  [NSPredicate predicateWithFormat:@"container != nil"]].count);
    }

merge:;
    // Phase 3: Merge MI + LS results (LS fields fill in MI gaps)
    NSMutableDictionary *merged = [NSMutableDictionary dictionaryWithDictionary:miResults];

    for (NSString *bundleID in lsResults) {
        NSDictionary *lsEntry = lsResults[bundleID];
        if (![lsEntry isKindOfClass:[NSDictionary class]]) continue;

        NSMutableDictionary *existing = [merged[bundleID] mutableCopy];
        if (!existing) {
            existing = [NSMutableDictionary dictionary];
        }

        for (NSString *key in lsEntry) {
            id val = lsEntry[key];
            existing[key] = val;
        }

        merged[bundleID] = existing;
    }

    NSLog(@"[5013:ls] workspace: %lu MobileInstallation: %lu merged: %lu",
          (unsigned long)lsResults.count,
          (unsigned long)miResults.count,
          (unsigned long)merged.count);

    return merged;
}

#pragma mark - appInfoForBundleID

NSDictionary *appInfoForBundleID(NSString *bundleID) {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    result[@"name"] = bundleID;

    Class proxyClass = NSClassFromString(@"LSApplicationProxy");
    if (!proxyClass) return result;

    SEL proxySel = NSSelectorFromString(@"applicationProxyForIdentifier:");
    if (![proxyClass respondsToSelector:proxySel]) return result;

    id proxy = ((id (*)(id, SEL, id))objc_msgSend)(proxyClass, proxySel, bundleID);
    if (!proxy) return result;

    // Verify this proxy matches the requested bundle ID
    NSArray *verifySelectors = @[@"applicationIdentifier", @"bundleIdentifier"];
    BOOL found = NO;
    for (NSString *selName in verifySelectors) {
        SEL sel = NSSelectorFromString(selName);
        if ([proxy respondsToSelector:sel]) {
            id val = ((id (*)(id, SEL))objc_msgSend)(proxy, sel);
            if ([val isKindOfClass:[NSString class]] && [val isEqualToString:bundleID]) {
                found = YES;
                break;
            }
        }
    }
    if (!found) return result;

    result[@"found"] = (__bridge id)kCFBooleanTrue;

    // Get bundle for localized info
    NSBundle *bundle = nil;
    SEL bundleURLSel = NSSelectorFromString(@"bundleURL");
    if ([proxy respondsToSelector:bundleURLSel]) {
        NSURL *url = ((id (*)(id, SEL))objc_msgSend)(proxy, bundleURLSel);
        if ([url isKindOfClass:[NSURL class]] && url) {
            bundle = [NSBundle bundleWithURL:url];
        }
    }

    NSDictionary *localizedInfo = [bundle localizedInfoDictionary];
    NSDictionary *infoDict = [bundle infoDictionary];

    // Name: prefer localized CFBundleDisplayName, fall back to info dict
    NSString *name = stringForFirstKey(localizedInfo, @[@"CFBundleDisplayName"]);
    if (!name.length) {
        name = stringForFirstKey(infoDict, @[@"CFBundleDisplayName", @"CFBundleName"]);
    }
    if (name.length) {
        result[@"name"] = name;
    }

    // If name still equals bundleID, try proxy's own name selectors
    if ([result[@"name"] isEqualToString:bundleID]) {
        NSArray *nameSelectors = @[@"localizedName", @"localizedShortName", @"itemName"];
        for (NSString *selName in nameSelectors) {
            SEL sel = NSSelectorFromString(selName);
            if ([proxy respondsToSelector:sel]) {
                id val = ((id (*)(id, SEL))objc_msgSend)(proxy, sel);
                if ([val isKindOfClass:[NSString class]] && [val length] > 0) {
                    result[@"name"] = val;
                    break;
                }
            }
        }
    }

    // Version from info dict
    NSString *version = stringForFirstKey(infoDict, @[@"CFBundleShortVersionString"]);
    if (version.length) {
        result[@"version"] = version;
    }

    // Fall back to proxy's shortVersionString
    if (!result[@"version"]) {
        SEL versionSel = NSSelectorFromString(@"shortVersionString");
        if ([proxy respondsToSelector:versionSel]) {
            id val = ((id (*)(id, SEL))objc_msgSend)(proxy, versionSel);
            if ([val isKindOfClass:[NSString class]] && [val length] > 0) {
                result[@"version"] = val;
            }
        }
    }

    // Container path
    NSArray *containerSelectors = @[@"dataContainerURL", @"bundleContainerURL"];
    for (NSString *selName in containerSelectors) {
        SEL sel = NSSelectorFromString(selName);
        if ([proxy respondsToSelector:sel]) {
            id val = ((id (*)(id, SEL))objc_msgSend)(proxy, sel);
            NSString *path = nil;
            if ([val isKindOfClass:[NSURL class]]) {
                path = [val path];
            } else if ([val isKindOfClass:[NSString class]]) {
                path = val;
            }
            if (path.length) {
                result[@"container"] = path;
                break;
            }
        }
    }

    return result;
}
