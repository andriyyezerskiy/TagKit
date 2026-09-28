//
//  TKTagFile.mm
//  TagKit
//
//  Created by Andriy Yezerskiy on 27/09/2026.
//

#import "TKTagFile.h"

#include <taglib/fileref.h>
#include <taglib/tfile.h>
#include <taglib/tpropertymap.h>
#include <taglib/tvariant.h>

static NSString *const TKTagFileErrorDomain = @"TagKit";

static NSError *TKError(NSString *description) {
    return [NSError errorWithDomain:TKTagFileErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey: description}];
}

static NSString *TKString(const TagLib::String &string) {
    return [NSString stringWithUTF8String:string.toCString(true)] ?: @"";
}

static TagLib::String TKTagString(NSString *string) {
    return TagLib::String(string.UTF8String, TagLib::String::UTF8);
}

@implementation TKTagFile

+ (NSDictionary<NSString *, NSArray<NSString *> *> *)propertiesOfFileAtPath:(NSString *)path error:(NSError **)error {
    TagLib::FileRef file(path.fileSystemRepresentation);

    if (file.isNull() || !file.file()) {
        if (error) {
            *error = TKError(@"The file's tags can't be read.");
        }

        return nil;
    }

    NSMutableDictionary<NSString *, NSArray<NSString *> *> *properties = [NSMutableDictionary dictionary];

    for (const auto &[key, values] : file.file()->properties()) {
        NSMutableArray<NSString *> *strings = [NSMutableArray arrayWithCapacity:values.size()];

        for (const auto &value : values) {
            [strings addObject:TKString(value)];
        }

        properties[TKString(key)] = strings;
    }

    return properties;
}

+ (NSData *)coverOfFileAtPath:(NSString *)path {
    TagLib::FileRef file(path.fileSystemRepresentation);

    if (file.isNull() || !file.file()) {
        return nil;
    }

    const auto pictures = file.file()->complexProperties("PICTURE");
    NSData *first = nil;

    for (const auto &picture : pictures) {
        const auto data = picture.value("data").toByteVector();
        NSData *image = [NSData dataWithBytes:data.data() length:data.size()];

        if (picture.value("pictureType").toString() == "Front Cover") {
            return image;
        }

        if (!first) {
            first = image;
        }
    }

    return first;
}

+ (BOOL)writeProperties:(NSDictionary<NSString *, NSArray<NSString *> *> *)properties
         removingKeys:(NSArray<NSString *> *)removedKeys
                cover:(NSData *)cover
        coverMIMEType:(NSString *)coverMIMEType
        replacesCover:(BOOL)replacesCover
        toFileAtPath:(NSString *)path
                error:(NSError **)error {
    TagLib::FileRef file(path.fileSystemRepresentation);

    if (file.isNull() || !file.file()) {
        if (error) {
            *error = TKError(@"The file's tags can't be read.");
        }

        return NO;
    }

    TagLib::PropertyMap map = file.file()->properties();

    for (NSString *key in removedKeys) {
        map.erase(TKTagString(key));
    }

    for (NSString *key in properties) {
        TagLib::StringList values;

        for (NSString *value in properties[key]) {
            values.append(TKTagString(value));
        }

        map.replace(TKTagString(key), values);
    }

    file.file()->setProperties(map);

    if (replacesCover) {
        TagLib::List<TagLib::VariantMap> pictures;

        if (cover) {
            TagLib::VariantMap picture;
            picture.insert("data", TagLib::ByteVector(static_cast<const char *>(cover.bytes), static_cast<unsigned int>(cover.length)));
            picture.insert("mimeType", TKTagString(coverMIMEType ?: @"image/jpeg"));
            picture.insert("pictureType", TagLib::String("Front Cover"));
            pictures.append(picture);
        }

        file.file()->setComplexProperties("PICTURE", pictures);
    }

    if (!file.save()) {
        if (error) {
            *error = TKError(@"The tags couldn't be saved to the file.");
        }

        return NO;
    }

    return YES;
}

@end
