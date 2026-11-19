// Stub header — LSApplicationWorkspace (CoreServices private)
// Actual class loaded at runtime via NSClassFromString in app_info.m
#ifndef LS_APPLICATION_WORKSPACE_STUB_H
#define LS_APPLICATION_WORKSPACE_STUB_H

#import <Foundation/Foundation.h>

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (NSArray *)allInstalledApplications;
- (NSArray *)allApplications;
@end

@interface LSApplicationProxy : NSObject
@property (nonatomic, readonly) NSString *applicationIdentifier;
@property (nonatomic, readonly) NSString *localizedName;
@property (nonatomic, readonly) NSURL *bundleURL;
@property (nonatomic, readonly) NSURL *dataContainerURL;
@property (nonatomic, readonly) NSString *applicationType;
@property (nonatomic, readonly) NSString *shortVersionString;
@end

#endif
