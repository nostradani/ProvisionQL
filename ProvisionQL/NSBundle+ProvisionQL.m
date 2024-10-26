//
//  NSBundle+ProvisionQL.m
//  ProvisionQL
//
//  Created by Daniel Muhra on 26.10.24.
//  Copyright © 2024 Evgeny Aleksandrov. All rights reserved.
//

#import "NSBundle+ProvisionQL.h"
#import "Shared.h"

@implementation NSBundle (ProvisionQL)

+ (NSBundle*) pluginBundle {
    return [NSBundle bundleWithIdentifier:kPluginBundleId];
}

@end
