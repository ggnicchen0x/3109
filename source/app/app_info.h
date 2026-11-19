// app_info.h — Installed app enumeration via private APIs
// Reconstructed from 5013 v3.2.17 binary

#ifndef APP_INFO_H
#define APP_INFO_H

#import <Foundation/Foundation.h>

// Enumerate all installed apps using MobileInstallation + LSApplicationWorkspace
// Returns NSDictionary mapping bundleID -> {name, container, version}
NSDictionary *installedAppInfo(void);

// Get detailed info for a single bundle ID via LSApplicationProxy
// Returns NSDictionary with keys: name, container, version, found (kCFBooleanTrue if exists)
NSDictionary *appInfoForBundleID(NSString *bundleID);

#endif // APP_INFO_H
