//
//  TKTagFile.h
//  TagKit
//
//  Created by Andriy Yezerskiy on 27/09/2026.
//
//  TagLib's unified property map and pictures, for any format it reads. Property names are TagLib's
//  upper-case ones, such as TITLE, ALBUMARTIST and TRACKNUMBER.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TKTagFile : NSObject

/// Every property in the file, each with one or more values. Returns nil when TagLib can't read the file.
+ (nullable NSDictionary<NSString *, NSArray<NSString *> *> *)propertiesOfFileAtPath:(NSString *)path error:(NSError **)error
    NS_SWIFT_NAME(properties(ofFileAtPath:));

/// The front cover, or the first picture when none is marked as the front cover.
+ (nullable NSData *)coverOfFileAtPath:(NSString *)path
    NS_SWIFT_NAME(cover(ofFileAtPath:));

/// Sets the given properties, removes the given keys, and, when `replacesCover` is set, replaces every picture
/// with `cover` (or removes them all when it's nil). Other properties are left as they were.
+ (BOOL)writeProperties:(NSDictionary<NSString *, NSArray<NSString *> *> *)properties
         removingKeys:(NSArray<NSString *> *)removedKeys
                cover:(nullable NSData *)cover
        coverMIMEType:(nullable NSString *)coverMIMEType
        replacesCover:(BOOL)replacesCover
        toFileAtPath:(NSString *)path
                error:(NSError **)error
    NS_SWIFT_NAME(writeProperties(_:removingKeys:cover:coverMIMEType:replacesCover:toFileAtPath:));

@end

NS_ASSUME_NONNULL_END
