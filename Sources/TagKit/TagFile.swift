//
//  TagFile.swift
//  TagKit
//
//  Created by Andriy Yezerskiy on 27/09/2026.
//

import Foundation
import TagBridge

/// Reads and writes an audio file's tags. Both touch the file directly, so callers coordinate access to files
/// that iCloud Drive or another app might also be using.
public enum TagFile {

    // MARK: - Actions
    public static func read(_ url: URL) throws -> AudioTags {
        let properties = try TKTagFile.properties(ofFileAtPath: url.path(percentEncoded: false))

        return AudioTags(properties: properties, cover: TKTagFile.cover(ofFileAtPath: url.path(percentEncoded: false)))
    }

    /// Writes every tag craete manages, removing the ones that are `nil`. Tags it doesn't manage are left alone.
    /// The cover is only replaced when `writesCover` is set, as rewriting a large picture is slow.
    public static func write(_ tags: AudioTags, to url: URL, writesCover: Bool = false) throws {
        let values = tags.properties

        try TKTagFile.writeProperties(
            values.compactMapValues { $0.map { [$0] } },
            removingKeys: values.filter { $0.value == nil }.map(\.key),
            cover: tags.cover,
            coverMIMEType: tags.cover.map(mimeType),
            replacesCover: writesCover,
            toFileAtPath: url.path(percentEncoded: false)
        )
    }

    // MARK: - Helpers
    private static func mimeType(of image: Data) -> String {
        image.starts(with: [0x89, 0x50, 0x4E, 0x47]) ? "image/png" : "image/jpeg"
    }
}
