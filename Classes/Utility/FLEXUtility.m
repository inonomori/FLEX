//
//  FLEXUtility.m
//  Flipboard
//
//  Created by Ryan Olson on 4/18/14.
//  Copyright (c) 2014 Flipboard. All rights reserved.
//

#import "FLEXColor.h"
#import "FLEXUtility.h"
#import "FLEXResources.h"
#import <ImageIO/ImageIO.h>
#import <zlib.h>
#import <objc/runtime.h>

@implementation FLEXUtility

+ (UIColor *)consistentRandomColorForObject:(id)object
{
    CGFloat hue = (((NSUInteger)object >> 4) % 256) / 255.0;
    return [UIColor colorWithHue:hue saturation:1.0 brightness:1.0 alpha:1.0];
}

+ (NSString *)descriptionForView:(UIView *)view includingFrame:(BOOL)includeFrame
{
    NSString *description = [[view class] description];
    
    NSString *viewControllerDescription = [[[self viewControllerForView:view] class] description];
    if ([viewControllerDescription length] > 0) {
        description = [description stringByAppendingFormat:@" (%@)", viewControllerDescription];
    }
    
    if (includeFrame) {
        description = [description stringByAppendingFormat:@" %@", [self stringForCGRect:view.frame]];
    }
    
    if ([view.accessibilityLabel length] > 0) {
        description = [description stringByAppendingFormat:@" · %@", view.accessibilityLabel];
    }
    
    return description;
}

+ (NSString *)stringForCGRect:(CGRect)rect
{
    return [NSString stringWithFormat:@"{(%g, %g), (%g, %g)}", rect.origin.x, rect.origin.y, rect.size.width, rect.size.height];
}

+ (UIViewController *)viewControllerForView:(UIView *)view
{
    UIViewController *viewController = nil;
    SEL viewDelSel = NSSelectorFromString(@"_viewDelegate");
    if ([view respondsToSelector:viewDelSel]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        viewController = [view performSelector:viewDelSel];
#pragma clang diagnostic pop
    }
    return viewController;
}

+ (UIViewController *)viewControllerForAncestralView:(UIView *)view
{
    UIViewController *viewController = nil;
    SEL viewDelSel = NSSelectorFromString([NSString stringWithFormat:@"%@ewControllerForAncestor", @"_vi"]);
    if ([view respondsToSelector:viewDelSel]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        viewController = [view performSelector:viewDelSel];
#pragma clang diagnostic pop
    }
    return viewController;
}

+ (NSString *)detailDescriptionForView:(UIView *)view
{
    return [NSString stringWithFormat:@"frame %@", [self stringForCGRect:view.frame]];
}

+ (UIImage *)circularImageWithColor:(UIColor *)color radius:(CGFloat)radius
{
    CGFloat diameter = radius * 2.0;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(diameter, diameter), NO, 0.0);
    CGContextRef imageContext = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(imageContext, [color CGColor]);
    CGContextFillEllipseInRect(imageContext, CGRectMake(0, 0, diameter, diameter));
    UIImage *circularImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return circularImage;
}

+ (UIColor *)hierarchyIndentPatternColor
{
    static UIColor *patternColor = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UIImage *indentationPatternImage = [FLEXResources hierarchyIndentPattern];
        patternColor = [UIColor colorWithPatternImage:indentationPatternImage];

#if FLEX_AT_LEAST_IOS13_SDK
        if (@available(iOS 13.0, *)) {
            // Create a dark mode version
            UIGraphicsBeginImageContextWithOptions(indentationPatternImage.size, NO, indentationPatternImage.scale);
            [[FLEXColor iconColor] set];
            [indentationPatternImage drawInRect:CGRectMake(0, 0, indentationPatternImage.size.width, indentationPatternImage.size.height)];
            UIImage *darkModePatternImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();

            // Create dynamic color provider
            patternColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
                return (traitCollection.userInterfaceStyle == UIUserInterfaceStyleLight
                        ? [UIColor colorWithPatternImage:indentationPatternImage]
                        : [UIColor colorWithPatternImage:darkModePatternImage]);
            }];
        }
#endif
    });

    return patternColor;
}

+ (NSString *)applicationImageName
{
    return [NSBundle mainBundle].executablePath;
}

+ (NSString *)applicationName
{
    return [FLEXUtility applicationImageName].lastPathComponent;
}

+ (NSString *)safeDescriptionForObject:(id)object
{
    // Don't assume that we have an NSObject subclass.
    // Check to make sure the object responds to the description methods.
    NSString *description = nil;
    if ([object respondsToSelector:@selector(debugDescription)]) {
        description = [object debugDescription];
    } else if ([object respondsToSelector:@selector(description)]) {
        description = [object description];
    }
    return description;
}

+ (NSString *)safeDebugDescriptionForObject:(id)object
{
    NSString *description = [self safeDescriptionForObject:object];
    if (!description) {
        NSString *cls = NSStringFromClass(object_getClass(object));
        if (object_isClass(object)) {
            description = [cls stringByAppendingString:@" class (no description)"];
       } else {
           description = [cls stringByAppendingString:@" instance (no description)"];
       }
    }

    return description;
}

+ (NSString *)addressOfObject:(id)object
{
    return [NSString stringWithFormat:@"%p", object];
}

+ (UIFont *)defaultFontOfSize:(CGFloat)size
{
    return [UIFont fontWithName:@"HelveticaNeue" size:size];
}

+ (UIFont *)defaultTableViewCellLabelFont
{
    return [self defaultFontOfSize:12.0];
}

+ (NSString *)stringByEscapingHTMLEntitiesInString:(NSString *)originalString
{
    static NSDictionary<NSString *, NSString *> *escapingDictionary = nil;
    static NSRegularExpression *regex = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        escapingDictionary = @{ @" " : @"&nbsp;",
                                @">" : @"&gt;",
                                @"<" : @"&lt;",
                                @"&" : @"&amp;",
                                @"'" : @"&apos;",
                                @"\"" : @"&quot;",
                                @"«" : @"&laquo;",
                                @"»" : @"&raquo;"
                                };
        regex = [NSRegularExpression regularExpressionWithPattern:@"(&|>|<|'|\"|«|»)" options:0 error:NULL];
    });
    
    NSMutableString *mutableString = [originalString mutableCopy];
    
    NSArray<NSTextCheckingResult *> *matches = [regex matchesInString:mutableString options:0 range:NSMakeRange(0, [mutableString length])];
    for (NSTextCheckingResult *result in [matches reverseObjectEnumerator]) {
        NSString *foundString = [mutableString substringWithRange:result.range];
        NSString *replacementString = escapingDictionary[foundString];
        if (replacementString) {
            [mutableString replaceCharactersInRange:result.range withString:replacementString];
        }
    }
    
    return [mutableString copy];
}

+ (UIInterfaceOrientationMask)infoPlistSupportedInterfaceOrientationsMask
{
    NSArray<NSString *> *supportedOrientations = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"UISupportedInterfaceOrientations"];
    UIInterfaceOrientationMask supportedOrientationsMask = 0;
    if ([supportedOrientations containsObject:@"UIInterfaceOrientationPortrait"]) {
        supportedOrientationsMask |= UIInterfaceOrientationMaskPortrait;
    }
    if ([supportedOrientations containsObject:@"UIInterfaceOrientationMaskLandscapeRight"]) {
        supportedOrientationsMask |= UIInterfaceOrientationMaskLandscapeRight;
    }
    if ([supportedOrientations containsObject:@"UIInterfaceOrientationMaskPortraitUpsideDown"]) {
        supportedOrientationsMask |= UIInterfaceOrientationMaskPortraitUpsideDown;
    }
    if ([supportedOrientations containsObject:@"UIInterfaceOrientationLandscapeLeft"]) {
        supportedOrientationsMask |= UIInterfaceOrientationMaskLandscapeLeft;
    }
    return supportedOrientationsMask;
}

+ (UIImage *)thumbnailedImageWithMaxPixelDimension:(NSInteger)dimension fromImageData:(NSData *)data
{
    UIImage *thumbnail = nil;
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((__bridge CFDataRef)data, 0);
    if (imageSource) {
        NSDictionary<NSString *, id> *options = @{ (__bridge id)kCGImageSourceCreateThumbnailWithTransform : @YES,
                                                   (__bridge id)kCGImageSourceCreateThumbnailFromImageAlways : @YES,
                                                   (__bridge id)kCGImageSourceThumbnailMaxPixelSize : @(dimension) };

        CGImageRef scaledImageRef = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, (__bridge CFDictionaryRef)options);
        if (scaledImageRef) {
            thumbnail = [UIImage imageWithCGImage:scaledImageRef];
            CFRelease(scaledImageRef);
        }
        CFRelease(imageSource);
    }
    return thumbnail;
}

+ (NSString *)stringFromRequestDuration:(NSTimeInterval)duration
{
    NSString *string = @"0s";
    if (duration > 0.0) {
        if (duration < 1.0) {
            string = [NSString stringWithFormat:@"%dms", (int)(duration * 1000)];
        } else if (duration < 10.0) {
            string = [NSString stringWithFormat:@"%.2fs", duration];
        } else {
            string = [NSString stringWithFormat:@"%.1fs", duration];
        }
    }
    return string;
}

+ (NSString *)statusCodeStringFromURLResponse:(NSURLResponse *)response
{
    NSString *httpResponseString = nil;
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        NSString *statusCodeDescription = nil;
        if (httpResponse.statusCode == 200) {
            // Prefer OK to the default "no error"
            statusCodeDescription = @"OK";
        } else {
            statusCodeDescription = [NSHTTPURLResponse localizedStringForStatusCode:httpResponse.statusCode];
        }
        httpResponseString = [NSString stringWithFormat:@"%ld %@", (long)httpResponse.statusCode, statusCodeDescription];
    }
    return httpResponseString;
}

+ (BOOL)isErrorStatusCodeFromURLResponse:(NSURLResponse *)response
{
    NSIndexSet *errorStatusCodes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(400, 200)];
    
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        return [errorStatusCodes containsIndex:httpResponse.statusCode];
    }
    
    return NO;
}

+ (NSDictionary<NSString *, id> *)dictionaryFromQuery:(NSString *)query
{
    NSMutableDictionary<NSString *, id> *queryDictionary = [NSMutableDictionary dictionary];

    // [a=1, b=2, c=3]
    NSArray<NSString *> *queryComponents = [query componentsSeparatedByString:@"&"];
    for (NSString *keyValueString in queryComponents) {
        // [a, 1]
        NSArray<NSString *> *components = [keyValueString componentsSeparatedByString:@"="];
        if ([components count] == 2) {
            NSString *key = [[components firstObject] stringByRemovingPercentEncoding];
            id value = [[components lastObject] stringByRemovingPercentEncoding];

            // Handle multiple entries under the same key as an array
            id existingEntry = queryDictionary[key];
            if (existingEntry) {
                if ([existingEntry isKindOfClass:[NSArray class]]) {
                    value = [existingEntry arrayByAddingObject:value];
                } else {
                    value = @[existingEntry, value];
                }
            }
            
            [queryDictionary setObject:value forKey:key];
        }
    }

    return queryDictionary;
}

+ (NSString *)prettyJSONStringFromData:(NSData *)data
{
    NSString *prettyString = nil;
    
    id jsonObject = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    if ([NSJSONSerialization isValidJSONObject:jsonObject]) {
        prettyString = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:jsonObject options:NSJSONWritingPrettyPrinted error:NULL] encoding:NSUTF8StringEncoding];
        // NSJSONSerialization escapes forward slashes. We want pretty json, so run through and unescape the slashes.
        prettyString = [prettyString stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"];
    } else {
        prettyString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    
    return prettyString;
}

+ (BOOL)isValidJSONData:(NSData *)data
{
    return [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] ? YES : NO;
}

// Thanks to the following links for help with this method
// https://www.cocoanetics.com/2012/02/decompressing-files-into-memory/
// https://github.com/nicklockwood/GZIP
+ (NSData *)inflatedDataFromCompressedData:(NSData *)compressedData
{
    NSData *inflatedData = nil;
    NSUInteger compressedDataLength = [compressedData length];
    if (compressedDataLength > 0) {
        z_stream stream;
        stream.zalloc = Z_NULL;
        stream.zfree = Z_NULL;
        stream.avail_in = (uInt)compressedDataLength;
        stream.next_in = (void *)[compressedData bytes];
        stream.total_out = 0;
        stream.avail_out = 0;

        NSMutableData *mutableData = [NSMutableData dataWithLength:compressedDataLength * 1.5];
        if (inflateInit2(&stream, 15 + 32) == Z_OK) {
            int status = Z_OK;
            while (status == Z_OK) {
                if (stream.total_out >= [mutableData length]) {
                    mutableData.length += compressedDataLength / 2;
                }
                stream.next_out = (uint8_t *)[mutableData mutableBytes] + stream.total_out;
                stream.avail_out = (uInt)([mutableData length] - stream.total_out);
                status = inflate(&stream, Z_SYNC_FLUSH);
            }
            if (inflateEnd(&stream) == Z_OK) {
                if (status == Z_STREAM_END) {
                    mutableData.length = stream.total_out;
                    inflatedData = [mutableData copy];
                }
            }
        }
    }
    return inflatedData;
}

+ (NSArray<UIWindow *> *)allWindows
{
    BOOL includeInternalWindows = YES;
    BOOL onlyVisibleWindows = NO;

    // Obfuscating selector allWindowsIncludingInternalWindows:onlyVisibleWindows:
    NSArray<NSString *> *allWindowsComponents = @[@"al", @"lWindo", @"wsIncl", @"udingInt", @"ernalWin", @"dows:o", @"nlyVisi", @"bleWin", @"dows:"];
    SEL allWindowsSelector = NSSelectorFromString([allWindowsComponents componentsJoinedByString:@""]);

    NSMethodSignature *methodSignature = [[UIWindow class] methodSignatureForSelector:allWindowsSelector];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];

    invocation.target = [UIWindow class];
    invocation.selector = allWindowsSelector;
    [invocation setArgument:&includeInternalWindows atIndex:2];
    [invocation setArgument:&onlyVisibleWindows atIndex:3];
    [invocation invoke];

    __unsafe_unretained NSArray<UIWindow *> *windows = nil;
    [invocation getReturnValue:&windows];
    return windows;
}

+ (void)alert:(NSString *)title message:(NSString *)message from:(UIViewController *)viewController
{
    [[[UIAlertView alloc] initWithTitle:title
                                message:message
                               delegate:nil
                      cancelButtonTitle:nil
                      otherButtonTitles:@"Dismiss", nil] show];
}

+ (SEL)swizzledSelectorForSelector:(SEL)selector
{
    return NSSelectorFromString([NSString stringWithFormat:@"_flex_swizzle_%x_%@", arc4random(), NSStringFromSelector(selector)]);
}

+ (BOOL)instanceRespondsButDoesNotImplementSelector:(SEL)selector class:(Class)cls
{
    if ([cls instancesRespondToSelector:selector]) {
        unsigned int numMethods = 0;
        Method *methods = class_copyMethodList(cls, &numMethods);
        
        BOOL implementsSelector = NO;
        for (int index = 0; index < numMethods; index++) {
            SEL methodSelector = method_getName(methods[index]);
            if (selector == methodSelector) {
                implementsSelector = YES;
                break;
            }
        }
        
        free(methods);
        
        if (!implementsSelector) {
            return YES;
        }
    }
    
    return NO;
}

+ (void)replaceImplementationOfKnownSelector:(SEL)originalSelector onClass:(Class)class withBlock:(id)block swizzledSelector:(SEL)swizzledSelector
{
    // This method is only intended for swizzling methods that are know to exist on the class.
    // Bail if that isn't the case.
    Method originalMethod = class_getInstanceMethod(class, originalSelector);
    if (!originalMethod) {
        return;
    }
    
    IMP implementation = imp_implementationWithBlock(block);
    class_addMethod(class, swizzledSelector, implementation, method_getTypeEncoding(originalMethod));
    Method newMethod = class_getInstanceMethod(class, swizzledSelector);
    method_exchangeImplementations(originalMethod, newMethod);
}

+ (void)replaceImplementationOfSelector:(SEL)selector withSelector:(SEL)swizzledSelector forClass:(Class)cls withMethodDescription:(struct objc_method_description)methodDescription implementationBlock:(id)implementationBlock undefinedBlock:(id)undefinedBlock
{
    if ([self instanceRespondsButDoesNotImplementSelector:selector class:cls]) {
        return;
    }
    
    IMP implementation = imp_implementationWithBlock((id)([cls instancesRespondToSelector:selector] ? implementationBlock : undefinedBlock));
    
    Method oldMethod = class_getInstanceMethod(cls, selector);
    if (oldMethod) {
        class_addMethod(cls, swizzledSelector, implementation, methodDescription.types);
        
        Method newMethod = class_getInstanceMethod(cls, swizzledSelector);
        
        method_exchangeImplementations(oldMethod, newMethod);
    } else {
        class_addMethod(cls, selector, implementation, methodDescription.types);
    }
}

@end
