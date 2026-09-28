// swift-tools-version: 6.0

import PackageDescription

/// Reads and writes audio file tags with TagLib, across ID3, FLAC and Vorbis comments, MP4, AIFF and WAV.
/// TagBridge wraps TagLib's C++ in Objective-C++, so the app needn't turn on C++ interoperability.
///
/// TagLib's source is vendored in `Sources/taglib` rather than fetched, so builds never pull code that hasn't been
/// reviewed. It's CXXTagLib 2.3.2 (github.com/sbooth/CXXTagLib, commit 9e499ea0a69d107791ac0a2fe9d6a59cf401c6f9),
/// TagLib packaged for SwiftPM, unchanged. Its licence, MPL 1.1 or LGPL 2.1, is in `Sources/taglib/LICENSE.txt`.
/// To update, copy a reviewed release's `Sources/taglib` over it and update the version and commit here.
let package = Package(
    name: "TagKit",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .visionOS(.v2)
    ],
    products: [
        .library(name: "TagKit", targets: ["TagKit"])
    ],
    targets: [
        .target(
            name: "taglib",
            exclude: ["LICENSE.txt"],
            cxxSettings: [
                .define("HAVE_GCC_BYTESWAP", to: "1"),
                .define("HAVE_ZLIB", to: "1"),
                .headerSearchPath("include/taglib"),
                .headerSearchPath("utfcpp/source"),
                .headerSearchPath("."),
                .headerSearchPath("matroska"),
                .headerSearchPath("matroska/ebml"),
                .headerSearchPath("mod"),
                .headerSearchPath("riff"),
                .headerSearchPath("toolkit")
            ],
            linkerSettings: [
                .linkedLibrary("z")
            ]
        ),
        .target(
            name: "TagBridge",
            dependencies: ["taglib"]
        ),
        .target(
            name: "TagKit",
            dependencies: ["TagBridge"]
        )
    ],
    cxxLanguageStandard: .cxx17
)
