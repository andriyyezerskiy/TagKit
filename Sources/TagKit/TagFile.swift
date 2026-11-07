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

    // MARK: - Properties
    /// The extensions of the formats TagLib can tag. Formats such as CAF, AU and Wave64 play but can't hold tags.
    private static let supportedExtensions: Set<String> = TKTagFile.supportedExtensions

    // MARK: - Actions
    /// Whether tags can be written into a file of this kind, judged by its extension without opening it.
    public static func canWrite(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    public static func read(_ url: URL) throws -> AudioTags {
        let properties = try TKTagFile.properties(ofFileAtPath: url.path(percentEncoded: false))

        return AudioTags(properties: properties, cover: TKTagFile.cover(ofFileAtPath: url.path(percentEncoded: false)))
    }

    /// Writes every tag craete manages, removing the ones that are `nil`. Tags it doesn't manage are left alone.
    /// The cover is only replaced when `writesCover` is set, as rewriting a large picture is slow, and the file's
    /// other pictures, such as a back cover, are kept.
    public static func write(_ tags: AudioTags, to url: URL, writesCover: Bool = false) throws {
        let path = url.path(percentEncoded: false)
        let values = tags.properties(separateTotals: TKTagFile.keepsTotalsSeparately(inFileAtPath: path))

        try TKTagFile.writeProperties(
            values.compactMapValues { $0.map { [$0] } },
            removingKeys: values.filter { $0.value == nil }.map(\.key),
            cover: tags.cover,
            coverMIMEType: tags.cover.map(mimeType),
            replacesCover: writesCover,
            toFileAtPath: path
        )
    }

    // MARK: - Helpers
    private static func mimeType(of image: Data) -> String {
        image.starts(with: [0x89, 0x50, 0x4E, 0x47]) ? "image/png" : "image/jpeg"
    }
}
