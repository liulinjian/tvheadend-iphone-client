//
//  TVHImageCache.m
//  TvhClient
//
//  Created by zipleen on 4/16/13.
//  Copyright (c) 2013 zipleen. All rights reserved.
//

#import "TVHImageCache.h"

@implementation TVHImageCache

+ (CGSize)sizeFromImage:(UIImage*)image withContentMode:(UIViewContentMode)contentMode bounds:(CGSize)bounds {
    CGFloat horizontalRatio = bounds.width / image.size.width;
    CGFloat verticalRatio = bounds.height / image.size.height;
    CGFloat ratio;
    
    switch (contentMode) {
        case UIViewContentModeScaleAspectFill:
            ratio = MAX(horizontalRatio, verticalRatio);
            break;
            
        case UIViewContentModeScaleAspectFit:
            ratio = MIN(horizontalRatio, verticalRatio);
            break;
            
        default:
            [NSException raise:NSInvalidArgumentException format:@"Unsupported content mode: %d", contentMode];
    }
    
    CGSize newSize = CGSizeMake(image.size.width * ratio, image.size.height * ratio);
    return newSize;
}

- (UIImage *)imageManager:(SDWebImageManager *)imageManager transformDownloadedImage:(UIImage *)image withURL:(NSURL *)imageURL {
    return [TVHImageCache resizeImage:image];
}

+ (UIImage*)resizeImage:(UIImage*)image {
    // I tried working with this http://vocaro.com/trevor/blog/2009/10/12/resize-a-uiimage-the-right-way/
    // but it didn't work quite well..
    CGSize newSize = [TVHImageCache sizeFromImage:image withContentMode:UIViewContentModeScaleAspectFit bounds:CGSizeMake(120, 100)];
    UIGraphicsBeginImageContextWithOptions(newSize, NO, [UIScreen mainScreen].scale);
    [image drawInRect:CGRectMake(0,0,newSize.width,newSize.height)];
    UIImage* newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}
@end
