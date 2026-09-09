import Foundation

guard CommandLine.arguments.count == 3 else {
    fputs("usage: package_icns.swift <iconset-dir> <output.icns>\n", stderr)
    exit(2)
}

let iconset = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])

// PNG-backed ICNS element types. Include both the modern large sizes and
// the duplicate 1x/@2x slots used by Finder and Dock on different scales.
let elements: [(String, String)] = [
    ("ic11", "icon_16x16@2x.png"),
    ("ic12", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic13", "icon_128x128@2x.png"),
    ("ic08", "icon_256x256.png"),
    ("ic14", "icon_256x256@2x.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png")
]

var chunks = Data()
for (type, filename) in elements {
    let png = try Data(contentsOf: iconset.appendingPathComponent(filename))
    var typeData = Data(type.utf8)
    var length = UInt32(8 + png.count).bigEndian
    typeData.append(Data(bytes: &length, count: MemoryLayout<UInt32>.size))
    typeData.append(png)
    chunks.append(typeData)
}

var result = Data("icns".utf8)
var totalLength = UInt32(8 + chunks.count).bigEndian
result.append(Data(bytes: &totalLength, count: MemoryLayout<UInt32>.size))
result.append(chunks)
try result.write(to: output)
