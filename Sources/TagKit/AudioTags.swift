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

    /// Reads from TagLib's property map, where a position may be `3`, `3/12` or `0/12`, with the total in its own
    /// field. A number of 0 means there isn't one.
    init(properties: [String: [String]], cover: Data?) {
        func text(_ key: String) -> String? {
            properties[key]?.first.flatMap { $0.isEmpty ? nil : $0 }
        }

        func positive(_ text: some StringProtocol) -> Int? {
            Int(text.trimmingCharacters(in: .whitespaces)).flatMap { $0 > 0 ? $0 : nil }
        }

        func position(_ key: String) -> (Int?, Int?) {
            let parts = text(key)?.split(separator: "/", omittingEmptySubsequences: false)

            return (parts?.first.flatMap(positive), parts?.dropFirst().first.flatMap(positive))
        }

        let track = position("TRACKNUMBER")
        let disc = position("DISCNUMBER")

        title = text("TITLE")
        artist = text("ARTIST")
        album = text("ALBUM")
        albumArtist = text("ALBUMARTIST")
        trackNumber = track.0
        trackTotal = track.1 ?? (text("TRACKTOTAL") ?? text("TOTALTRACKS")).flatMap(positive)
        discNumber = disc.0
        discTotal = disc.1 ?? (text("DISCTOTAL") ?? text("TOTALDISCS")).flatMap(positive)
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

    // MARK: - Helpers
    /// TagLib's property map for writing: the value of each tag craete manages, or `nil` to remove it. Vorbis
    /// comments keep totals in their own fields; other formats keep them with the number, as `3/12`, or `0/12` when
    /// there's no number. The other spellings of the totals are removed so they can't contradict the new ones.
    func properties(separateTotals: Bool) -> [String: String?] {
        let positions: [String: String?] = if separateTotals {
            [
                "TRACKNUMBER": Self.count(trackNumber).map(String.init),
                "TRACKTOTAL": Self.count(trackTotal).map(String.init),
                "DISCNUMBER": Self.count(discNumber).map(String.init),
                "DISCTOTAL": Self.count(discTotal).map(String.init)
            ]
        } else {
            [
                "TRACKNUMBER": Self.position(trackNumber, of: trackTotal),
                "TRACKTOTAL": nil,
                "DISCNUMBER": Self.position(discNumber, of: discTotal),
                "DISCTOTAL": nil
            ]
        }

        return [
            "TITLE": title,
            "ARTIST": artist,
            "ALBUM": album,
            "ALBUMARTIST": albumArtist,
            "TOTALTRACKS": nil,
            "TOTALDISCS": nil,
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
        .merging(positions) { $1 }
        .mapValues { value in value.flatMap { $0.isEmpty ? nil : $0 } }
    }

    private static func position(_ number: Int?, of total: Int?) -> String? {
        switch (count(number), count(total)) {
        case (let number?, let total?): "\(number)/\(total)"
        case (let number?, nil): String(number)
        case (nil, let total?): "0/\(total)"
        case (nil, nil): nil
        }
    }

    /// A track or disc number or total, which 0 or less means is missing.
    private static func count(_ value: Int?) -> Int? {
        value.flatMap { $0 > 0 ? $0 : nil }
    }
}
