//
//  ProvisioninProfileThumbnailData.m
//  ProvisionQL
//
//  Created by Daniel Muhra on 31.10.24.
//  Copyright © 2024 Evgeny Aleksandrov. All rights reserved.
//

#import "ProvisioninProfileThumbnailData.h"

@implementation ProvisioninProfileThumbnailData

- (id)initWithAppIcon:(NSImage *)appIcon devicesCount:(NSUInteger)devicesCount expStatus:(int)expStatus {
    self = [super init];
    
    if (self != nil) {
        self->_appIcon = appIcon;
        self->_devicesCount = devicesCount;
        self->_expStatus = expStatus;
    }
    
    return self;
}

@end
