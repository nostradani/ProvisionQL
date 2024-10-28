#import "Shared.h"

@import ZIPFoundationObjC;

ZFOArchiveEntry* findEntry(ZFOArchive *archive, NSString* pattern) {
    NSString* replaced = [[pattern stringByReplacingOccurrencesOfString:@"." withString:@"\\."] stringByReplacingOccurrencesOfString:@"*" withString:@".*"];
    NSString* regexPattern = [NSString stringWithFormat:@"^%@$", replaced];
    NSRegularExpression *regex = [[NSRegularExpression alloc] initWithPattern:regexPattern options:0 error:nil];
    
    return [archive findFirst:^BOOL(ZFOArchiveEntry * _Nonnull entry) {
        NSString* path = entry.path;
        return [regex firstMatchInString:path options:0 range:NSMakeRange(0, path.length)] != nil;
    }];
}

NSData *unzipFile(NSURL *url, NSString *filePath) {
    ZFOArchive *archive = [[ZFOArchive alloc] initWithUrl:url accessMode:ZFOAccessModeRead error:NULL];
    ZFOArchiveEntry* entry = findEntry(archive, filePath);
    
    if (entry == nil) {
        return nil;
    }
    
    NSMutableData* result = [NSMutableData data];
    
    BOOL success = [archive extract:entry bufferSize:[ZFOArchive defaultReadChunkSize] skipCRC32:true progress:nil error:NULL consumer:^(NSData * _Nonnull data) {
        [result appendData:data];
    }];
    
    return success ? result : nil;
}

BOOL unzipFileToDir(NSURL *url, NSString *targetDir, NSString *filePath) {
    ZFOArchive *archive = [[ZFOArchive alloc] initWithUrl:url accessMode:ZFOAccessModeRead error:NULL];
    ZFOArchiveEntry* entry = findEntry(archive, filePath);
    
    if (entry == nil) {
        return NO;
    }
    
    NSURL* target = [[NSURL fileURLWithPath:targetDir] URLByAppendingPathComponent:[filePath lastPathComponent]];
    BOOL result = [archive extract:entry to:target bufferSize:[ZFOArchive defaultReadChunkSize] skipCRC32:true allowUncontainedSymlinks:false progress:nil error:NULL];
    return result;
}

NSImage *roundCorners(NSImage *image) {
    NSImage *existingImage = image;
    NSSize existingSize = [existingImage size];
    NSImage *composedImage = [[NSImage alloc] initWithSize:existingSize];

    [composedImage lockFocus];
    [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];

    NSRect imageFrame = NSRectFromCGRect(CGRectMake(0, 0, existingSize.width, existingSize.height));
    NSBezierPath *clipPath = [NSBezierPath bezierPathWithIOS7RoundedRect:imageFrame cornerRadius:existingSize.width * 0.225];
    [clipPath setWindingRule:NSWindingRuleEvenOdd];
    [clipPath addClip];

    [image drawAtPoint:NSZeroPoint fromRect:NSMakeRect(0, 0, existingSize.width, existingSize.height) operation:NSCompositingOperationSourceOver fraction:1];

    [composedImage unlockFocus];

    return composedImage;
}

int expirationStatus(NSDate *date, NSCalendar *calendar) {
    int result = 0;

    if (date) {
        NSDateComponents *dateComponents = [calendar components:NSCalendarUnitDay fromDate:[NSDate date] toDate:date options:0];
        if ([date compare:[NSDate date]] == NSOrderedAscending) {
            // expired
            result = 0;
        } else if (dateComponents.day < 30) {
            // expiring
            result = 1;
        } else {
            // valid
            result = 2;
        }
    }

    return result;
}

NSImage *imageFromApp(NSURL *URL, NSString *dataType, NSString *fileName) {
    NSImage *appIcon = nil;

    if ([dataType isEqualToString:kDataType_xcode_archive]) {
        // get the embedded icon for the iOS app
        NSURL *appsDir = [URL URLByAppendingPathComponent:@"Products/Applications/"];
        if (!appsDir) {
            return nil;
        }

        NSArray *dirFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:appsDir.path error:nil];
        NSString *appName = dirFiles.firstObject;
        if (!appName) {
            return nil;
        }

        NSURL *appURL = [appsDir URLByAppendingPathComponent:appName];
        NSArray *appContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:appURL.path error:nil];
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF contains %@", fileName];
        NSString *appIconFullName = [appContents filteredArrayUsingPredicate:predicate].lastObject;
        if (!appIconFullName) {
            return nil;
        }

        NSURL *appIconFullURL = [appURL URLByAppendingPathComponent:appIconFullName];
        appIcon = [[NSImage alloc] initWithContentsOfURL:appIconFullURL];
    } else if([dataType isEqualToString:kDataType_ipa]) {
        NSData *data = unzipFile(URL, @"iTunesArtwork");
        if (!data && fileName.length > 0) {
            data = unzipFile(URL, [NSString stringWithFormat:@"Payload/*.app/%@*", fileName]);
        }
        if (data != nil) {
            appIcon = [[NSImage alloc] initWithData:data];
        }
    }

    return appIcon;
}

NSArray *iconsListForDictionary(NSDictionary *iconsDict) {
    if ([iconsDict isKindOfClass:[NSDictionary class]]) {
        id primaryIconDict = [iconsDict objectForKey:@"CFBundlePrimaryIcon"];
        if ([primaryIconDict isKindOfClass:[NSDictionary class]]) {
            id tempIcons = [primaryIconDict objectForKey:@"CFBundleIconFiles"];
            if ([tempIcons isKindOfClass:[NSArray class]]) {
                return tempIcons;
            }
        }
    }

    return nil;
}

NSString *mainIconNameForApp(NSDictionary *appPropertyList) {
    NSArray *icons;
    NSString *iconName;

    //Check for CFBundleIcons (since 5.0)
    icons = iconsListForDictionary([appPropertyList objectForKey:@"CFBundleIcons"]);
    if (!icons) {
        icons = iconsListForDictionary([appPropertyList objectForKey:@"CFBundleIcons~ipad"]);
    }

    if (!icons) {
        //Check for CFBundleIconFiles (since 3.2)
        id tempIcons = [appPropertyList objectForKey:@"CFBundleIconFiles"];
        if ([tempIcons isKindOfClass:[NSArray class]]) {
            icons = tempIcons;
        }
    }

    if (icons) {
        //Search some patterns for primary app icon (120x120)
        NSArray *matches = @[@"120",@"60"];

        for (NSString *match in matches) {
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF contains[c] %@",match];
            NSArray *results = [icons filteredArrayUsingPredicate:predicate];
            if ([results count]) {
                iconName = [results firstObject];
                break;
            }
        }

        //If no one matches any pattern, just take last item
        if (!iconName) {
            iconName = [icons lastObject];
        }
    } else {
        //Check for CFBundleIconFile (legacy, before 3.2)
        NSString *legacyIcon = [appPropertyList objectForKey:@"CFBundleIconFile"];
        if ([legacyIcon length]) {
            iconName = legacyIcon;
        }
    }

    return iconName;
}
