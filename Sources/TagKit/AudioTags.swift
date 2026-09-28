//
//  AudioTags.swift
//  TagKit
//
//  Created by Andriy Yezerskiy on 27/09/2026.
//

import Foundation

/// The tags craete reads and writes, in any format TagLib supports. `nil` means the file doesn't have that tag,
/// and writing `nil` removes it.
public struct AudioTags: Equatable, Sendable {

    // MARK: - Properties
    public var title: String?
    public var artist: String?
    public var album: String?
    public var albumArtist: String?
    public var trackNumber: Int?
    public var trackTotal: Int?
    public var discNumber: Int?
    public var discTotal: Int?
    /// As written in the file, usually a year or `YYYY-MM-DD`.
    public var releaseDate: String?
    public var genre: String?
    public var composer: String?
    public var label: String?
    public var catalogNumber: String?
    public var isrc: String?
    public var barcode: String?
    public var bpm: Int?
    public var comment: String?
    public var lyrics: String?
    public var isCompilation: Bool = false
    public var cover: Data?

    // MARK: - Init
    public init() {}

    /// Reads from TagLib's property map, where a position may be `3` or `3/12`, with the total in its own field.
    init(properties: [String: [String]], cover: Data?) {
        func text(_ key: String) -> String? {
            properties[key]?.first.flatMap { $0.isEmpty ? nil : $0 }
        }

        func position(_ key: String) -> (Int?, Int?) {
            let parts = text(key)?.split(separator: "/").map { Int($0.trimmingCharacters(in: .whitespaces)) }

            return (parts?.first ?? nil, parts?.dropFirst().first ?? nil)
        }

        let track = position("TRACKNUMBER")
        let disc = position("DISCNUMBER")

        title = text("TITLE")
        artist = text("ARTIST")
        album = text("ALBUM")
        albumArtist = text("ALBUMARTIST")
        trackNumber = track.0
        trackTotal = track.1 ?? text("TRACKTOTAL").flatMap(Int.init)
        discNumber = disc.0
        discTotal = disc.1 ?? text("DISCTOTAL").flatMap(Int.init)
        releaseDate = text("DATE")
        genre = text("GENRE")
        composer = text("COMPOSER")
        label = text("LABEL")
        catalogNumber = text("CATALOGNUMBER")
        isrc = text("ISRC")
        barcode = text("BARCODE")
        bpm = text("BPM").flatMap { Int(Double($0) ?? 0) }.flatMap { $0 == 0 ? nil : $0 }
        comment = text("COMMENT")
        lyrics = text("LYRICS")
        isCompilation = text("COMPILATION") == "1"
        self.cover = cover
    }

    // MARK: - Computed Properties
    /// TagLib's property map for writing: the value of each tag craete manages, or `nil` to remove it.
    var properties: [String: String?] {
        [
            "TITLE": title,
            "ARTIST": artist,
            "ALBUM": album,
            "ALBUMARTIST": albumArtist,
            "TRACKNUMBER": Self.position(trackNumber, of: trackTotal),
            "DISCNUMBER": Self.position(discNumber, of: discTotal),
            "DATE": releaseDate,
            "GENRE": genre,
            "COMPOSER": composer,
            "LABEL": label,
            "CATALOGNUMBER": catalogNumber,
            "ISRC": isrc,
            "BARCODE": barcode,
            "BPM": bpm.map(String.init),
            "COMMENT": comment,
            "LYRICS": lyrics,
            "COMPILATION": isCompilation ? "1" : nil
        ]
        .mapValues { value in value.flatMap { $0.isEmpty ? nil : $0 } }
    }

    // MARK: - Helpers
    private static func position(_ number: Int?, of total: Int?) -> String? {
        guard let number, number > 0 else { return nil }

        return total.map { "\(number)/\($0)" } ?? String(number)
    }
}
