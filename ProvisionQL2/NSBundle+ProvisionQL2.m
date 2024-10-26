//
//  NSBundle+ProvisionQL2.m
//  ProvisionQL2
//
//  Created by Daniel Muhra on 26.10.24.
//  Copyright © 2024 Evgeny Aleksandrov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSBundle+ProvisionQL.h"
#import "PreviewProvider.h"

@implementation NSBundle (ProvisionQL)

+ (NSBundle *)pluginBundle {
    return [NSBundle bundleForClass:[PreviewProvider class]];
}

@end
