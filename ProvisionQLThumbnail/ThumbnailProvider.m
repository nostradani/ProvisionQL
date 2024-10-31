//
//  ThumbnailProvider.m
//  ProvisionQLThumbnail
//
//  Created by Daniel Muhra on 31.10.24.
//  Copyright © 2024 Evgeny Aleksandrov. All rights reserved.
//

#import "ThumbnailProvider.h"
#import "Shared.h"
#import "ProvisioninProfileThumbnailData.h"


NSImage* generateThumbnailForArchive(NSURL *URL, NSString *dataType);
ProvisioninProfileThumbnailData* generateProvisioningProfileData(NSURL *URL, NSString *dataType, BOOL iconMode);
void drawProvisioningProfileThumbnail(CGContextRef _context, NSImage* appIcon, NSUInteger devicesCount, int expStatus, BOOL iconMode);

@implementation ThumbnailProvider

- (void)provideThumbnailForFileRequest:(QLFileThumbnailRequest *)request completionHandler:(void (^)(QLThumbnailReply * _Nullable, NSError * _Nullable))handler {
    
    // There are three ways to provide a thumbnail through a QLThumbnailReply. Only one of them should be used.
    
    NSString *fileUTI = [[UTType typeWithFilenameExtension:request.fileURL.pathExtension] identifier];

    if ([fileUTI isEqualToString:kDataType_ipa] || [fileUTI isEqualToString:kDataType_xcode_archive]) {
        QLThumbnailReply* reply = [QLThumbnailReply replyWithContextSize:request.maximumSize currentContextDrawingBlock:^BOOL{
            CGContextRef context = [NSGraphicsContext currentContext].CGContext;

            // Clear the background to be fully transparent
            CGContextClearRect(context, CGRectMake(0, 0, request.maximumSize.width, request.maximumSize.height));
            
            
            NSImage* appImage = generateThumbnailForArchive(request.fileURL, fileUTI);
            // Calculate aspect-fit rectangle
            CGSize imageSize = appImage.size;
            CGSize maxSize = request.maximumSize;
            
            CGFloat scale = MIN(maxSize.width / imageSize.width, maxSize.height / imageSize.height);
            CGSize scaledSize = CGSizeMake(imageSize.width * scale, imageSize.height * scale);
            
            CGRect imageRect = CGRectMake((maxSize.width - scaledSize.width) / 2.0,
                                          (maxSize.height - scaledSize.height) / 2.0,
                                          scaledSize.width,
                                          scaledSize.height);

            // Draw the image in the calculated aspect-fit rectangle
            [appImage drawInRect:imageRect];
            
            return YES;
        }];
        reply.extensionBadge = @"ASDF";
        
        handler(reply, nil);
    }
    else {
        handler([QLThumbnailReply replyWithContextSize:request.maximumSize drawingBlock:^BOOL(CGContextRef  _Nonnull context) {
            ProvisioninProfileThumbnailData* data = generateProvisioningProfileData(request.fileURL, fileUTI, YES);
            drawProvisioningProfileThumbnail(context, data.appIcon, data.devicesCount, data.expStatus, YES);
            // Draw the thumbnail here.
        
            // Return YES if the thumbnail was successfully drawn inside this block.
            return YES;
        }], nil);
    }
    
    /*
     
     // Second way: Draw the thumbnail into a context passed to your block, set up with Core Graphics's coordinate system.
     handler([QLThumbnailReply replyWithContextSize:request.maximumSize drawingBlock:^BOOL(CGContextRef  _Nonnull context) {
     // Draw the thumbnail here.
     
     // Return YES if the thumbnail was successfully drawn inside this block.
     return YES;
     }], nil);
     
     // Third way: Set an image file URL.
     handler([QLThumbnailReply replyWithImageFileURL:[NSBundle.mainBundle URLForResource:@"fileThumbnail" withExtension:@"jpg"]], nil);
     
     */
}

@end
