/**
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "RNCImageEditor.h"

#import <UIKit/UIKit.h>

#import <React/RCTConvert.h>
#import <React/RCTLog.h>
#import <React/RCTUtils.h>

#import <React/RCTImageLoader.h>
#import <React/RCTImageStoreManager.h>
#import <RCTImage/RCTImageUtils.h>

@implementation RNCImageEditor

RCT_EXPORT_MODULE()

@synthesize bridge = _bridge;

/**
 * Crops an image and adds the result to the image store.
 *
 * @param imageRequest An image URL
 * @param cropData Dictionary with `offset`, `size` and `displaySize`.
 *        `offset` and `size` are relative to the full-resolution image size.
 *        `displaySize` is an optimization - if specified, the image will
 *        be scaled down to `displaySize` rather than `size`.
 *        All units are in px (not points).
 */
RCT_EXPORT_METHOD(cropImage:(NSURLRequest *)imageRequest
                  cropData:(NSDictionary *)cropData
                  successCallback:(RCTResponseSenderBlock)successCallback
                  errorCallback:(RCTResponseErrorBlock)errorCallback)
{
  CGRect rect = {
    [RCTConvert CGPoint:cropData[@"offset"]],
    [RCTConvert CGSize:cropData[@"size"]]
  };

  [_bridge.imageLoader loadImageWithURLRequest:imageRequest callback:^(NSError *error, UIImage *image) {
    if (error) {
      errorCallback(error);
      return;
    }

    // Crop image
    CGSize targetSize = rect.size;
    CGRect targetRect = {{-rect.origin.x, -rect.origin.y}, image.size};
    
    CGAffineTransform transform = RCTTransformFromTargetRect(image.size, targetRect);
    UIImage *croppedImage = RLVTransformImage(image, targetSize, image.scale, transform);

    // Scale image
    if (cropData[@"displaySize"]) {
      targetSize = [RCTConvert CGSize:cropData[@"displaySize"]]; // in pixels
      RCTResizeMode resizeMode = [RCTConvert RCTResizeMode:cropData[@"resizeMode"] ?: @"contain"];
      targetRect = RCTTargetRect(croppedImage.size, targetSize, 1, resizeMode);
      transform = RCTTransformFromTargetRect(croppedImage.size, targetRect);
      croppedImage = RLVTransformImage(croppedImage, targetSize, image.scale, transform);
    }

    // Store image
    [self->_bridge.imageStoreManager storeImage:croppedImage withBlock:^(NSString *croppedImageTag) {
      if (!croppedImageTag) {
        NSString *errorMessage = @"Error storing cropped image in RCTImageStoreManager";
        RCTLogWarn(@"%@", errorMessage);
        errorCallback(RCTErrorWithMessage(errorMessage));
        return;
      }
      successCallback(@[croppedImageTag]);
    }];
  }];
}

UIImage *__nullable RLVTransformImage(UIImage *image,
                                      CGSize destSize,
                                      CGFloat destScale,
                                      CGAffineTransform transform)
{
    if (destSize.width <= 0 | destSize.height <= 0 || destScale <= 0) {
        return nil;
    }
    
    BOOL opaque = !RCTImageHasAlpha(image.CGImage);
    UIGraphicsBeginImageContextWithOptions(destSize, opaque, destScale);
    [[UIColor whiteColor] setFill];
    CGRect targetRect = {{0, 0}, destSize};
    UIRectFill( targetRect );
    CGContextRef currentContext = UIGraphicsGetCurrentContext();
    CGContextConcatCTM(currentContext, transform);
    [image drawAtPoint:CGPointZero];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}


@end

