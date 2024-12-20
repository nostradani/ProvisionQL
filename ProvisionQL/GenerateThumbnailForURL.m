#import "Shared.h"
#import "NSBundle+ProvisionQL.h"
#import "ProvisioninProfileThumbnailData.h"

//Layout constants
#define BADGE_MARGIN        10.0
#define MIN_BADGE_WIDTH     40.0
#define BADGE_HEIGHT        75.0
#define BADGE_MARGIN_X      60.0
#define BADGE_MARGIN_Y      80.0

//Drawing constants
#define BADGE_BG_COLOR          [NSColor lightGrayColor]
#define BADGE_VALID_COLOR       [NSColor colorWithCalibratedRed:(0/255.0) green:(98/255.0) blue:(25/255.0) alpha:1]
#define BADGE_EXPIRING_COLOR    [NSColor colorWithCalibratedRed:(146/255.0) green:(95/255.0) blue:(28/255.0) alpha:1]
#define BADGE_EXPIRED_COLOR     [NSColor colorWithCalibratedRed:(141/255.0) green:(0/255.0) blue:(7/255.0) alpha:1]
#define BADGE_FONT              [NSFont boldSystemFontOfSize:64]


OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maxSize);
void CancelThumbnailGeneration(void *thisInterface, QLThumbnailRequestRef thumbnail);

NSImage* generateThumbnailForArchive(NSURL *URL, NSString *dataType) {
    NSData *appPlist = nil;
    NSImage *appIcon = nil;

    if ([dataType isEqualToString:kDataType_xcode_archive]) {
        // get the embedded plist for the iOS app
        NSURL *appsDir = [URL URLByAppendingPathComponent:@"Products/Applications/"];
        if (appsDir != nil) {
            NSArray *dirFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:appsDir.path error:nil];
            if (dirFiles.count > 0) {
                appPlist = [NSData dataWithContentsOfURL:[appsDir URLByAppendingPathComponent:[NSString stringWithFormat:@"%@/Info.plist", dirFiles[0]]]];
            }
        }
    } else if([dataType isEqualToString:kDataType_ipa]) {
        appPlist = unzipFile(URL, @"Payload/*.app/Info.plist");
    }
    
    NSDictionary *appPropertyList = [NSPropertyListSerialization propertyListWithData:appPlist options:0 format:NULL error:NULL];
    NSString *iconName = mainIconNameForApp(appPropertyList);
    appIcon = imageFromApp(URL, dataType, iconName);

    if (!appIcon) {
        NSURL *iconURL = [[NSBundle pluginBundle] URLForResource:@"defaultIcon" withExtension:@"png"];
        appIcon = [[NSImage alloc] initWithContentsOfURL:iconURL];
    }
    // image-only icons can be drawn efficiently.
    appIcon = roundCorners(appIcon);
    // if downscale, then this should respect retina resolution
//            if (appIcon.size.width > maxSize.width && appIcon.size.height > maxSize.height) {
//                [appIcon setSize:maxSize];
//            }
    
    return appIcon;
}

ProvisioninProfileThumbnailData* generateProvisioningProfileData(NSURL *URL, NSString *dataType, BOOL iconMode) {
    // use provisioning directly
    NSData *provisionData = [NSData dataWithContentsOfURL:URL];
    if (!provisionData) {
        NSLog(@"No provisionData for %@", URL);
        return nil;
    }

    NSUInteger devicesCount = 0;
    int expStatus = 0;

    NSImage *appIcon;
    if (iconMode) {
        NSURL *iconURL = [[NSBundle pluginBundle] URLForResource:@"blankIcon" withExtension:@"png"];
        appIcon = [[NSImage alloc] initWithContentsOfURL:iconURL];
    } else {
        appIcon = [[NSWorkspace sharedWorkspace] iconForFileType:dataType];
        [appIcon setSize:NSMakeSize(512,512)];
    }

    CMSDecoderRef decoder = NULL;
    CMSDecoderCreate(&decoder);
    CMSDecoderUpdateMessage(decoder, provisionData.bytes, provisionData.length);
    CMSDecoderFinalizeMessage(decoder);
    CFDataRef dataRef = NULL;
    CMSDecoderCopyContent(decoder, &dataRef);
    NSData *data = (NSData *)CFBridgingRelease(dataRef);
    CFRelease(decoder);

    if (!data) {
        return nil;
    }

    NSDictionary *propertyList = [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:NULL];
    id value = [propertyList objectForKey:@"ProvisionedDevices"];
    if ([value isKindOfClass:[NSArray class]]) {
        devicesCount = [value count];
    }

    value = [propertyList objectForKey:@"ExpirationDate"];
    if ([value isKindOfClass:[NSDate class]]) {
        expStatus = expirationStatus(value, [NSCalendar currentCalendar]);
    }

    return [[ProvisioninProfileThumbnailData alloc] init];
}

void drawProvisioningProfileThumbnail(CGContextRef _context, NSImage* appIcon, NSUInteger devicesCount, int expStatus, BOOL iconMode) {
    NSRect renderRect = NSMakeRect(0.0, 0.0, appIcon.size.width, appIcon.size.height);
    NSGraphicsContext *_graphicsContext = [NSGraphicsContext graphicsContextWithCGContext:(void *)_context flipped:NO];

    [NSGraphicsContext setCurrentContext:_graphicsContext];

    [appIcon drawInRect:renderRect];

    NSString *badge = [NSString stringWithFormat:@"%lu",(unsigned long)devicesCount];
    NSColor *outlineColor;

    if (expStatus == 2) {
        outlineColor = BADGE_VALID_COLOR;
    } else if (expStatus == 1) {
        outlineColor = BADGE_EXPIRING_COLOR;
    } else {
        outlineColor = BADGE_EXPIRED_COLOR;
    }

    NSMutableParagraphStyle *paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    paragraphStyle.lineBreakMode = NSLineBreakByTruncatingTail;
    paragraphStyle.alignment = NSTextAlignmentCenter;

    NSDictionary *attrDict = @{NSFontAttributeName : BADGE_FONT, NSForegroundColorAttributeName : outlineColor, NSParagraphStyleAttributeName: paragraphStyle};

    NSSize badgeNumSize = [badge sizeWithAttributes:attrDict];
    int badgeWidth = badgeNumSize.width + BADGE_MARGIN * 2;
    badgeWidth = MAX(badgeWidth, MIN_BADGE_WIDTH);

    int badgeX = renderRect.origin.x + BADGE_MARGIN_X;
    int badgeY = renderRect.origin.y + renderRect.size.height - BADGE_HEIGHT - BADGE_MARGIN_Y;
    if (!iconMode) {
        badgeX += 75;
        badgeY -= 10;
    }
    int badgeNumX = badgeX + BADGE_MARGIN;
    NSRect badgeRect = NSMakeRect(badgeX, badgeY, badgeWidth, BADGE_HEIGHT);

    NSBezierPath *badgePath = [NSBezierPath bezierPathWithRoundedRect:badgeRect xRadius:10 yRadius:10];
    [badgePath setLineWidth:8.0];
    [BADGE_BG_COLOR set];
    [badgePath fill];
    [outlineColor set];
    [badgePath stroke];

    [badge drawAtPoint:NSMakePoint(badgeNumX,badgeY) withAttributes:attrDict];
}

NSDictionary* generateImageDict(NSString* dataType) {
    
    static const NSString *IconFlavor;
    if (@available(macOS 10.15, *)) {
        IconFlavor = @"icon";
    } else {
        IconFlavor = @"IconFlavor";
    }
    NSDictionary *propertiesDict = nil;
    if ([dataType isEqualToString:kDataType_xcode_archive]) {
        // 0: Plain transparent, 1: Shadow, 2: Book, 3: Movie, 4: Address, 5: Image,
        // 6: Gloss, 7: Slide, 8: Square, 9: Border, 11: Calendar, 12: Pattern
        propertiesDict = @{IconFlavor : @(12)};
    } else {
        propertiesDict = @{IconFlavor : @(0)};
    }
    
    return propertiesDict;
}

/* -----------------------------------------------------------------------------
    Generate a thumbnail for file

   This function's job is to create thumbnail for designated file as fast as possible
   ----------------------------------------------------------------------------- */

OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maxSize) {
    OSStatus result = noErr;
    
    @autoreleasepool {
        NSURL *URL = (__bridge NSURL *)url;
        NSString *dataType = (__bridge NSString *)contentTypeUTI;
        
        // MARK: .ipa & .xarchive
        if ([dataType isEqualToString:kDataType_ipa] || [dataType isEqualToString:kDataType_xcode_archive]) {
            NSImage* appIcon = generateThumbnailForArchive(URL, dataType);
            NSDictionary *propertiesDict = generateImageDict(dataType);
            
            if (appIcon != nil && !QLThumbnailRequestIsCancelled(thumbnail)) {
                QLThumbnailRequestSetImageWithData(thumbnail, (__bridge CFDataRef)[appIcon TIFFRepresentation], (__bridge CFDictionaryRef)propertiesDict);
            }
        }
        else {
            // MARK: .provisioning
            NSDictionary *optionsDict = (__bridge NSDictionary *)options;
            BOOL iconMode = ([optionsDict objectForKey:(NSString *)kQLThumbnailOptionIconModeKey]) ? YES : NO;
            
            ProvisioninProfileThumbnailData *data = generateProvisioningProfileData(URL, dataType, iconMode);
            if (data != nil && !QLThumbnailRequestIsCancelled(thumbnail)) {
                CGContextRef _context = QLThumbnailRequestCreateContext(thumbnail, data.appIcon.size, false, NULL);
                if (_context) {
                    drawProvisioningProfileThumbnail(_context, data.appIcon, data.devicesCount, data.expStatus, iconMode);
                    QLThumbnailRequestFlushContext(thumbnail, _context);
                    CFRelease(_context);
                }
            }
        }
    }
    
    return result;
}

void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview) {
    // Implement only if supported
}
