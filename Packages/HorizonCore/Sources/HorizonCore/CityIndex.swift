import Foundation

public struct City: Hashable, Sendable {
    public let name: String
    /// ISO 3166-1 alpha-2, turned into a country name by `Locale` at display time.
    public let countryCode: String
    public let coordinates: Coordinates
    public let population: Int
}

/// Reader for `cities15000.bin`, the offline city list built by `Tools/build_cities.py` from
/// GeoNames *cities15000* (CC BY 4.0). Cities are stored by decreasing population.
///
/// Layout, little endian: `"HZC1"`, count `UInt32`, then per city 20 bytes
/// (latitude `Float32`, longitude `Float32`, population `UInt32`, name offset `UInt32`,
/// name length `UInt16`, country code 2 ASCII bytes), then the UTF-8 names.
public struct CityIndex: Sendable {
    public enum FormatError: Error {
        case notACityFile
        case truncated
    }

    private static let magic = Data("HZC1".utf8)
    private static let headerSize = 8
    private static let recordSize = 20

    private let data: Data
    public let count: Int
    private let namesStart: Int

    public init(data: Data) throws {
        guard data.count >= Self.headerSize, data.prefix(4) == Self.magic else { throw FormatError.notACityFile }
        let data = Data(data)
        let count = Int(data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 4, as: UInt32.self) }.littleEndian)
        let namesStart = Self.headerSize + count * Self.recordSize
        guard data.count >= namesStart else { throw FormatError.truncated }
        self.data = data
        self.count = count
        self.namesStart = namesStart
    }

    public init(contentsOf url: URL) throws {
        try self.init(data: Data(contentsOf: url, options: .mappedIfSafe))
    }

    public func city(at index: Int) -> City {
        let record = record(at: index)
        return City(
            name: name(record),
            countryCode: record.countryCode,
            coordinates: Coordinates(latitude: Double(record.latitude), longitude: Double(record.longitude)),
            population: Int(record.population))
    }

    public func nearest(to coordinates: Coordinates) -> City? {
        var best: (index: Int, distance: Double)?
        for index in 0..<count {
            let record = record(at: index)
            // Cheap rejection before the trigonometry: one degree of latitude is about 111 km.
            if let best, abs(Double(record.latitude) - coordinates.latitude) * 111_000 > best.distance { continue }
            let distance = coordinates.distance(
                to: Coordinates(latitude: Double(record.latitude), longitude: Double(record.longitude)))
            if best == nil || distance < best!.distance {
                best = (index, distance)
            }
        }
        return best.map { city(at: $0.index) }
    }

    /// Cities whose name starts with `prefix`, ignoring case and accents, biggest first.
    public func search(prefix: String, limit: Int) -> [City] {
        let needle = Self.fold(prefix.trimmingCharacters(in: .whitespaces))
        var result: [City] = []
        for index in 0..<count where result.count < limit {
            let record = record(at: index)
            if needle.isEmpty || Self.fold(name(record)).hasPrefix(needle) {
                result.append(city(at: index))
            }
        }
        return result
    }

    // MARK: - Records

    private struct Record {
        let latitude: Float
        let longitude: Float
        let population: UInt32
        let nameOffset: Int
        let nameLength: Int
        let countryCode: String
    }

    private func record(at index: Int) -> Record {
        precondition((0..<count).contains(index))
        let offset = Self.headerSize + index * Self.recordSize
        return data.withUnsafeBytes { bytes in
            func u32(_ at: Int) -> UInt32 {
                bytes.loadUnaligned(fromByteOffset: offset + at, as: UInt32.self).littleEndian
            }
            let length = bytes.loadUnaligned(fromByteOffset: offset + 16, as: UInt16.self).littleEndian
            let countryCode = String(decoding: bytes[(offset + 18)..<(offset + 20)], as: UTF8.self)
            return Record(
                latitude: Float(bitPattern: u32(0)), longitude: Float(bitPattern: u32(4)), population: u32(8),
                nameOffset: Int(u32(12)), nameLength: Int(length), countryCode: countryCode)
        }
    }

    private func name(_ record: Record) -> String {
        let start = namesStart + record.nameOffset
        guard start + record.nameLength <= data.count else { return "" }
        return String(decoding: data[start..<(start + record.nameLength)], as: UTF8.self)
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
