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
    /// Each tag is written with one value, replacing any others the file has for it, so a file's own tags are better
    /// edited with `write(_:over:to:writesCover:)`. The cover is only replaced when `writesCover` is set, as
    /// rewriting a large picture is slow, and the file's other pictures, such as a back cover, are kept.
    public static func write(_ tags: AudioTags, to url: URL, writesCover: Bool = false) throws {
        let path = url.path(percentEncoded: false)
        let values = tags.properties(separateTotals: TKTagFile.keepsTotalsSeparately(inFileAtPath: path))

        try write(values, cover: tags.cover, writesCover: writesCover, to: path)
    }

    /// Writes only the tags that differ from `existing`, the file's tags as read just before, removing the ones that
    /// became `nil`. A tag that's the same keeps every value the file has for it, such as a second artist or genre,
    /// which `AudioTags` only reads the first of. A changed tag is written with its one value. The cover is only
    /// replaced when `writesCover` is set, and a file with nothing to change isn't touched.
    public static func write(_ tags: AudioTags, over existing: AudioTags, to url: URL, writesCover: Bool = false) throws {
        let path = url.path(percentEncoded: false)
        let separateTotals = TKTagFile.keepsTotalsSeparately(inFileAtPath: path)
        let values = tags.properties(separateTotals: separateTotals, changedFrom: existing)

        guard !values.isEmpty || writesCover else { return }

        try write(values, cover: tags.cover, writesCover: writesCover, to: path)
    }

    // MARK: - Helpers
    /// Sets the tags that have a value and removes the ones that are `nil`.
    private static func write(_ values: [String: String?], cover: Data?, writesCover: Bool, to path: String) throws {
        try TKTagFile.writeProperties(
            values.compactMapValues { $0.map { [$0] } },
            removingKeys: values.filter { $0.value == nil }.map(\.key),
            cover: cover,
            coverMIMEType: cover.map(mimeType),
            replacesCover: writesCover,
            toFileAtPath: path
        )
    }

    private static func mimeType(of image: Data) -> String {
        image.starts(with: [0x89, 0x50, 0x4E, 0x47]) ? "image/png" : "image/jpeg"
    }
}
