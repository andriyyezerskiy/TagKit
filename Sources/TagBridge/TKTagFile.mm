//
//  TKTagFile.mm
//  TagKit
//
//  Created by Andriy Yezerskiy on 27/09/2026.
//

#import "TKTagFile.h"

#include <taglib/fileref.h>
#include <taglib/flacfile.h>
#include <taglib/mp4atom.h>
#include <taglib/mp4file.h>
#include <taglib/mp4itemfactory.h>
#include <taglib/mp4tag.h>
#include <taglib/id3v1tag.h>
#include <taglib/id3v2tag.h>
#include <taglib/mpegfile.h>
#include <taglib/oggfile.h>
#include <taglib/tfile.h>
#include <taglib/tpropertymap.h>
#include <taglib/tvariant.h>

static NSString *const TKTagFileErrorDomain = @"TagKit";

/// The padding an MP4 file's tags may keep before they're written afresh to fit, as after a large cover is replaced
/// with a small one.
static const TagLib::offset_t TKMaximumMP4Padding = 64 * 1024;

static NSError *TKError(NSString *description) {
    return [NSError errorWithDomain:TKTagFileErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey: description}];
}

static NSString *TKString(const TagLib::String &string) {
    return [NSString stringWithUTF8String:string.toCString(true)] ?: @"";
}

static TagLib::String TKTagString(NSString *string) {
    return TagLib::String(string.UTF8String, TagLib::String::UTF8);
}

static TagLib::StringList TKTagStrings(NSArray<NSString *> *strings) {
    TagLib::StringList list;

    for (NSString *string in strings) {
        list.append(TKTagString(string));
    }

    return list;
}

/// Where the cover is among a file's pictures: the first front cover, or the first picture when none is marked
/// as one. -1 when the file has no pictures.
static int TKCoverIndex(const TagLib::List<TagLib::VariantMap> &pictures) {
    int index = 0;

    for (const auto &picture : pictures) {
        if (picture.value("pictureType").toString() == "Front Cover") {
            return index;
        }

        index++;
    }

    return pictures.isEmpty() ? -1 : 0;
}

/// Sets and removes only the given keys of an MP4 file's tags, in whatever case the file has them. TagLib's
/// `setProperties` writes every property back under an upper-case name, so a freeform atom such as iTunes'
/// `iTunSMPB` would gain a second copy called `ITUNSMPB`.
static void TKWriteMP4Properties(TagLib::MP4::Tag *tag, const TagLib::PropertyMap &properties, const TagLib::StringList &removedKeys) {
    const auto *factory = TagLib::MP4::ItemFactory::instance();
    TagLib::StringList replacedNames;

    for (const auto &[name, item] : tag->itemMap()) {
        const auto key = factory->propertyKeyForName(name.data(TagLib::String::Latin1)).upper();

        if (!key.isEmpty() && (properties.contains(key) || removedKeys.contains(key))) {
            replacedNames.append(name);
        }
    }

    for (const auto &name : replacedNames) {
        tag->removeItem(name);
    }

    for (const auto &[key, values] : properties) {
        if (const auto [name, item] = factory->itemFromProperty(key, values); item.isValid()) {
            tag->setItem(TagLib::String(name, TagLib::String::Latin1), item);
        }
    }
}

/// Replaces the cover that `coverOfFileAtPath:` reads, or removes it when `cover` is nil, keeping any other
/// pictures, such as a back cover, where they were.
static void TKReplaceCover(TagLib::File *file, NSData *cover, NSString *mimeType) {
    const auto pictures = file->complexProperties("PICTURE");
    const int coverIndex = TKCoverIndex(pictures);
    TagLib::VariantMap picture;
    TagLib::List<TagLib::VariantMap> replaced;
    int index = 0;

    if (cover) {
        picture.insert("data", TagLib::ByteVector(static_cast<const char *>(cover.bytes), static_cast<unsigned int>(cover.length)));
        picture.insert("mimeType", TKTagString(mimeType ?: @"image/jpeg"));
        picture.insert("pictureType", TagLib::String("Front Cover"));
    }

    for (const auto &existing : pictures) {
        if (index != coverIndex) {
            replaced.append(existing);
        } else if (cover) {
            replaced.append(picture);
        }

        index++;
    }

    if (coverIndex < 0 && cover) {
        replaced.append(picture);
    }

    file->setComplexProperties("PICTURE", replaced);
}

/// Saves the file. TagLib's MP3 and AAC save adds an ID3v1 tag, which can't hold most non-Latin text, so an ID3v1
/// tag is only kept up to date when the file already has one. TagLib's own copying between the two would remove
/// a track total with no number, `0/12`, so ID3v1 is given the year and track it can't read from `2019-05-01`
/// or `3/12` directly.
static bool TKSave(TagLib::File *file) {
    if (auto *mpeg = dynamic_cast<TagLib::MPEG::File *>(file)) {
        int tags = TagLib::MPEG::File::ID3v2;

        if (mpeg->hasID3v1Tag() && mpeg->ID3v1Tag() && mpeg->ID3v2Tag()) {
            mpeg->ID3v1Tag()->setYear(mpeg->ID3v2Tag()->year());
            mpeg->ID3v1Tag()->setTrack(mpeg->ID3v2Tag()->track());
            tags |= TagLib::MPEG::File::ID3v1;
        }

        return mpeg->save(tags, TagLib::File::StripNone, TagLib::ID3v2::v4, TagLib::File::DoNotDuplicate);
    }

    return file->save();
}

/// TagLib pads an MP4 file's tags with a `free` atom when they shrink, so the file would keep the size of the
/// largest cover it ever held. When the padding is large, the tags are stripped and written afresh, as long as
/// their metadata atom holds nothing else that stripping would lose.
static bool TKCompactMP4File(const char *path) {
    TagLib::MP4::File file(path, false);

    if (!file.isValid() || !file.tag()) {
        return true;
    }

    TagLib::MP4::Atoms atoms(&file);
    const auto ilst = atoms.path("moov", "udta", "meta", "ilst");
    TagLib::offset_t padding = 0;

    if (ilst.size() != 4) {
        return true;
    }

    for (const auto *child : ilst[2]->children()) {
        if (child->name() == "free") {
            padding += child->length();
        } else if (child->name() != "hdlr" && child->name() != "ilst") {
            return true;
        }
    }

    if (padding <= TKMaximumMP4Padding) {
        return true;
    }

    const TagLib::MP4::ItemMap items = file.tag()->itemMap();

    if (!file.strip()) {
        return false;
    }

    for (const auto &[name, item] : items) {
        file.tag()->setItem(name, item);
    }

    return file.save();
}

@implementation TKTagFile

+ (NSSet<NSString *> *)supportedExtensions {
    NSMutableSet<NSString *> *extensions = [NSMutableSet set];

    for (const auto &extension : TagLib::FileRef::defaultFileExtensions()) {
        [extensions addObject:TKString(extension).lowercaseString];
    }

    return extensions;
}

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
    const int index = TKCoverIndex(pictures);

    if (index < 0) {
        return nil;
    }

    const auto data = pictures[static_cast<unsigned int>(index)].value("data").toByteVector();

    return [NSData dataWithBytes:data.data() length:data.size()];
}

+ (BOOL)keepsTotalsSeparatelyInFileAtPath:(NSString *)path {
    TagLib::FileRef file(path.fileSystemRepresentation, false);

    return dynamic_cast<TagLib::FLAC::File *>(file.file()) || dynamic_cast<TagLib::Ogg::File *>(file.file());
}

+ (BOOL)writeProperties:(NSDictionary<NSString *, NSArray<NSString *> *> *)properties
         removingKeys:(NSArray<NSString *> *)removedKeys
                cover:(NSData *)cover
        coverMIMEType:(NSString *)coverMIMEType
        replacesCover:(BOOL)replacesCover
        toFileAtPath:(NSString *)path
                error:(NSError **)error {
    bool isMP4 = false;

    // The file is closed before an MP4 file is compacted, which opens it again.
    {
        TagLib::FileRef file(path.fileSystemRepresentation);

        if (file.isNull() || !file.file()) {
            if (error) {
                *error = TKError(@"The file's tags can't be read.");
            }

            return NO;
        }

        TagLib::PropertyMap changes;
        const TagLib::StringList removed = TKTagStrings(removedKeys);

        for (NSString *key in properties) {
            changes.replace(TKTagString(key), TKTagStrings(properties[key]));
        }

        if (auto *mp4 = dynamic_cast<TagLib::MP4::File *>(file.file())) {
            isMP4 = true;
            TKWriteMP4Properties(mp4->tag(), changes, removed);
        } else {
            TagLib::PropertyMap map = file.file()->properties();

            for (const auto &key : removed) {
                map.erase(key);
            }

            for (const auto &[key, values] : changes) {
                map.replace(key, values);
            }

            file.file()->setProperties(map);
        }

        if (replacesCover) {
            TKReplaceCover(file.file(), cover, coverMIMEType);
        }

        if (!TKSave(file.file())) {
            if (error) {
                *error = TKError(@"The tags couldn't be saved to the file.");
            }

            return NO;
        }
    }

    if (isMP4 && !TKCompactMP4File(path.fileSystemRepresentation)) {
        if (error) {
            *error = TKError(@"The tags couldn't be saved to the file.");
        }

        return NO;
    }

    return YES;
}

@end
