//
//  ProvisioninProfileThumbnailData.h
//  ProvisionQL
//
//  Created by Daniel Muhra on 31.10.24.
//  Copyright © 2024 Evgeny Aleksandrov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ProvisioninProfileThumbnailData : NSObject

@property(nonatomic, strong) NSImage* appIcon;
@property(nonatomic, assign) NSUInteger devicesCount;
@property(nonatomic, assign) int expStatus;

- (id) initWithAppIcon:(NSImage*) appIcon
          devicesCount: (NSUInteger) devicesCount
             expStatus: (int) expStatus;

@end

NS_ASSUME_NONNULL_END
