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

/// The lower-case extensions of the formats TagLib can tag, such as `mp3`, `flac` and `m4a`.
@property (class, readonly) NSSet<NSString *> *supportedExtensions;

/// Every property in the file, each with one or more values. Returns nil when TagLib can't read the file.
+ (nullable NSDictionary<NSString *, NSArray<NSString *> *> *)propertiesOfFileAtPath:(NSString *)path error:(NSError **)error
    NS_SWIFT_NAME(properties(ofFileAtPath:));

/// The front cover, or the first picture when none is marked as the front cover.
+ (nullable NSData *)coverOfFileAtPath:(NSString *)path
    NS_SWIFT_NAME(cover(ofFileAtPath:));

/// Whether the file keeps track and disc totals in their own fields, as Vorbis comments in FLAC and Ogg files do,
/// rather than with the number, as `3/12`.
+ (BOOL)keepsTotalsSeparatelyInFileAtPath:(NSString *)path
    NS_SWIFT_NAME(keepsTotalsSeparately(inFileAtPath:));

/// Sets the given properties, removes the given keys, and, when `replacesCover` is set, replaces the cover that
/// `coverOfFileAtPath:` reads with `cover` (or removes it when it's nil). Other properties and pictures are left
/// as they were.
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
