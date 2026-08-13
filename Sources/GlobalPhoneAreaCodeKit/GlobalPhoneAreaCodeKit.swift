import Foundation

// MARK: - Error Types

/// Errors that can occur when working with area code data
public enum AreaCodeError: Error, LocalizedError {
    case fileNotFound(String)
    case noFilesFound
    case invalidData(String)
    case decodingFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let code):
            return "Area code file for '\(code)' not found"
        case .noFilesFound:
            return "No area code data files found in bundle"
        case .invalidData(let reason):
            return "Invalid area code data: \(reason)"
        case .decodingFailed(let reason):
            return "Failed to decode area codes: \(reason)"
        }
    }
}

// MARK: - Data Model

/// Represents a phone area code with its associated geographic and metadata information
public struct AreaCode: Codable, Identifiable, Sendable, Hashable {
    public var id: String { e164 }
    public let code: String
    /// ISO 3166-1 alpha-2 country code (e.g. "US", "GB"). Normalized on decode.
    public let country: String
    public let region: String
    public let city: String
    public let e164: String
    public let notes: String
    /// Approximate centroid latitude for this area code, when available
    public let latitude: Double?
    /// Approximate centroid longitude for this area code, when available
    public let longitude: Double?
    
    private enum CodingKeys: String, CodingKey {
        case code, country, region, city, e164, notes, latitude, longitude
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(String.self, forKey: .code)
        country = AreaCode.normalizeCountryCode(try container.decode(String.self, forKey: .country))
        region = try container.decode(String.self, forKey: .region)
        city = try container.decode(String.self, forKey: .city)
        e164 = try container.decode(String.self, forKey: .e164)
        notes = try container.decode(String.self, forKey: .notes)
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
    }
    
    // MARK: - Normalization Helpers
    
    /// Strips all non-digit characters from a phone number string
    ///
    /// Use this to sanitize user input before lookups, e.g.
    /// `"+1 (212) 555-1234"` becomes `"12125551234"`.
    public static func digitsOnly(_ input: String) -> String {
        input.filter { $0.isASCII && $0.isNumber }
    }
    
    /// Normalizes a country identifier to ISO 3166-1 alpha-2
    ///
    /// Maps common non-ISO aliases (`"UK"` → `"GB"`, `"USA"` → `"US"`)
    /// and uppercases the result.
    public static func normalizeCountryCode(_ raw: String) -> String {
        let upper = raw.trimmingCharacters(in: .whitespaces).uppercased()
        switch upper {
        case "UK": return "GB"
        case "USA": return "US"
        default: return upper
        }
    }
    
    /// Returns the country's flag emoji
    public var flag: String {
        countryCodeToFlag(country)
    }
    
    /// Returns the localized country name derived from the ISO code via `Locale`
    public var countryName: String {
        Locale.current.localizedString(forRegionCode: country.uppercased()) ?? country
    }
    
    /// A formatted display name suitable for lists
    public var displayName: String {
        "\(flag) \(code) - \(city.isEmpty ? region : city)"
    }
    
    /// A subtitle showing location details
    public var subtitle: String {
        if city.isEmpty {
            return "\(region), \(countryName)"
        } else {
            return "\(city), \(region), \(countryName)"
        }
    }
    
    /// Formats a phone number with this area code in E.164 format
    public func formatPhoneNumber(_ localNumber: String) -> String {
        "+\(e164)\(localNumber)"
    }
    
    // MARK: - Hashable
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(e164)
    }
    
    // MARK: - Private Helpers
    
    private func countryCodeToFlag(_ countryCode: String) -> String {
        let code = AreaCode.normalizeCountryCode(countryCode)
        
        guard code.count == 2, code.allSatisfy({ $0.isASCII && $0.isLetter }) else {
            return "🌍"
        }
        
        // Convert ISO 3166-1 alpha-2 country code to flag emoji
        // Unicode flag emoji: Regional Indicator Symbol Letters
        let base: UInt32 = 127397
        var flagString = ""
        for scalar in code.unicodeScalars {
            if let flagScalar = UnicodeScalar(base + scalar.value) {
                flagString.append(String(flagScalar))
            }
        }
        
        return flagString.isEmpty ? "🌍" : flagString
    }
}

// MARK: - Library Logic

/// A thread-safe, lazy-loading manager for global phone area code data
///
/// `GlobalPhoneAreaCodeKit` provides async methods to look up area codes,
/// search for locations, and filter by country. Data is loaded on-demand
/// and cached for performance.
///
/// ## Usage
///
/// ```swift
/// let kit = GlobalPhoneAreaCodeKit.shared
///
/// // Resolve a full phone number to its area code (longest-prefix match)
/// let nyc = try await kit.resolve(fullE164: "+1 (212) 555-1234")
///
/// // Look up a specific area code
/// let results = try await kit.lookup(code: "212")
///
/// // Search for a city
/// let paris = try await kit.search("Paris")
///
/// // Get all codes for a country
/// let canadianCodes = try await kit.codes(forCountry: "CA")
/// ```
public actor GlobalPhoneAreaCodeKit {
    
    /// Shared singleton instance
    public static let shared = GlobalPhoneAreaCodeKit()
    
    // MARK: - Private State
    
    /// Cache of all loaded area codes
    private var allCodesCache: [AreaCode]?
    
    /// Cache of area codes by country code
    private var countryCache: [String: [AreaCode]] = [:]
    
    /// Cached E.164 prefix index for `lookup(e164:)`, `lookupLongestPrefix`, and `resolve(fullE164:)`
    private var e164Index: [String: AreaCode]?
    
    /// Length of the longest known E.164 prefix (bounds longest-prefix walks)
    private var maxE164Length = 0
    
    /// Whether data is currently being loaded
    private var isLoading = false
    
    /// Task for loading all codes (prevents duplicate loads)
    private var loadTask: Task<[AreaCode], Error>?
    
    private init() {}
    
    // MARK: - Public API
    
    /// Returns all available area codes
    ///
    /// Data is loaded lazily on first call and cached for subsequent calls.
    ///
    /// - Returns: Array of all area codes across all countries
    /// - Throws: `AreaCodeError` if data cannot be loaded
    public func getAllCodes() async throws -> [AreaCode] {
        // Return cached data if available
        if let cached = allCodesCache {
            return cached
        }
        
        // If already loading, wait for that task
        if let existingTask = loadTask {
            return try await existingTask.value
        }
        
        // Create new load task
        let task = Task<[AreaCode], Error> {
            try await loadAllFiles()
        }
        loadTask = task
        
        do {
            let codes = try await task.value
            allCodesCache = codes
            loadTask = nil
            return codes
        } catch {
            loadTask = nil
            throw error
        }
    }
    
    /// Look up area codes by code number
    ///
    /// Input is sanitized with `AreaCode.digitsOnly(_:)`, so formatted
    /// strings like `"(212)"` match as well.
    ///
    /// - Parameter code: The area code to search for (e.g., "212", "416")
    /// - Returns: Array of matching area codes (multiple entries for overlapping codes)
    /// - Throws: `AreaCodeError` if data cannot be loaded
    public func lookup(code: String) async throws -> [AreaCode] {
        let digits = AreaCode.digitsOnly(code)
        guard !digits.isEmpty else { return [] }
        let allCodes = try await getAllCodes()
        return allCodes.filter { $0.code == digits }
    }
    
    /// Look up an area code by exact E.164 prefix
    ///
    /// Input is sanitized with `AreaCode.digitsOnly(_:)`, so `"+1212"`
    /// and `"1212"` are equivalent. For matching a full phone number,
    /// use `resolve(fullE164:)` or `lookupLongestPrefix(e164:minLength:)`.
    ///
    /// - Parameter e164: The E.164 prefix to search for (e.g., "1212")
    /// - Returns: The matching area code, or nil if not found
    /// - Throws: `AreaCodeError` if data cannot be loaded
    public func lookup(e164: String) async throws -> AreaCode? {
        let digits = AreaCode.digitsOnly(e164)
        guard !digits.isEmpty else { return nil }
        let index = try await getE164Index()
        return index[digits]
    }
    
    /// Look up an area code by longest E.164 prefix match with a country-code bound
    ///
    /// Input is sanitized with `AreaCode.digitsOnly(_:)`. The candidate is truncated
    /// to the dataset's maximum key length, then trailing digits are dropped until a
    /// dictionary hit is found.
    ///
    /// `minLength` is an **exclusive** lower bound: candidates whose digit count is
    /// less than or equal to `minLength` are never tested. Callers typically pass the
    /// country calling code's digit length (e.g. `1` for NANP, `2` for India) so a
    /// bare country code cannot match as an area-code result.
    ///
    /// Prefer this when you already know the country-code length. Prefer
    /// `resolve(fullE164:)` for free-form numbers that may include a leading `00`
    /// international dialing prefix and should walk all the way down to length 1.
    ///
    /// - Parameters:
    ///   - e164: Digit string (no leading `+` required; non-digits are stripped)
    ///   - minLength: Exclusive lower bound on candidate length (usually country-code length)
    /// - Returns: The longest matching area code above `minLength`, or nil
    /// - Throws: `AreaCodeError` if data cannot be loaded
    public func lookupLongestPrefix(e164: String, minLength: Int) async throws -> AreaCode? {
        let digits = AreaCode.digitsOnly(e164)
        guard !digits.isEmpty else { return nil }
        
        let index = try await getE164Index()
        var candidate = digits.count > maxE164Length
            ? String(digits.prefix(maxE164Length))
            : digits
        
        while candidate.count > minLength {
            if let match = index[candidate] {
                return match
            }
            candidate.removeLast()
        }
        return nil
    }
    
    /// Resolve a full phone number to its area code using longest-prefix matching
    ///
    /// The input may contain any formatting (`+`, spaces, dashes, parentheses);
    /// it is reduced to digits before matching. A leading international dialing
    /// prefix `00` is stripped. The longest known E.164 prefix wins, e.g.
    /// `"+1 (212) 555-1234"` resolves to the `1212` entry rather than a shorter match.
    ///
    /// - Parameter fullE164: A full phone number in any common format
    /// - Returns: The area code whose E.164 prefix is the longest match, or nil
    /// - Throws: `AreaCodeError` if data cannot be loaded
    public func resolve(fullE164: String) async throws -> AreaCode? {
        var digits = AreaCode.digitsOnly(fullE164)
        if digits.hasPrefix("00") {
            digits.removeFirst(2)
        }
        guard !digits.isEmpty else { return nil }
        
        let index = try await getE164Index()
        var length = min(maxE164Length, digits.count)
        while length > 0 {
            if let match = index[String(digits.prefix(length))] {
                return match
            }
            length -= 1
        }
        return nil
    }
    
    /// Search area codes by city, region, or notes
    ///
    /// - Parameter query: Search string to match against city, region, or notes
    /// - Returns: Array of matching area codes
    /// - Throws: `AreaCodeError` if data cannot be loaded
    public func search(_ query: String) async throws -> [AreaCode] {
        let allCodes = try await getAllCodes()
        return allCodes.filter {
            $0.city.localizedCaseInsensitiveContains(query) ||
            $0.region.localizedCaseInsensitiveContains(query) ||
            $0.notes.localizedCaseInsensitiveContains(query)
        }
    }
    
    /// Get all area codes for a specific country
    ///
    /// This method uses a country-specific cache for better performance.
    /// Input is normalized to ISO 3166-1 alpha-2, so aliases like `"UK"`
    /// (for `"GB"`) and `"USA"` (for `"US"`) are accepted.
    ///
    /// - Parameter country: ISO 3166-1 alpha-2 country code (e.g., "US", "CA")
    /// - Returns: Array of area codes for the specified country
    /// - Throws: `AreaCodeError` if data cannot be loaded
    public func codes(forCountry country: String) async throws -> [AreaCode] {
        let normalizedCountry = AreaCode.normalizeCountryCode(country)
        
        // Check cache first
        if let cached = countryCache[normalizedCountry] {
            return cached
        }
        
        // Try loading specific country file first (more efficient)
        if let countryCodes = try? await loadFile(countryCode: normalizedCountry) {
            countryCache[normalizedCountry] = countryCodes
            return countryCodes
        }
        
        // Fall back to filtering all codes
        let allCodes = try await getAllCodes()
        let filtered = allCodes.filter { $0.country == normalizedCountry }
        
        // Cache the result
        countryCache[normalizedCountry] = filtered
        return filtered
    }
    
    /// Get autocomplete suggestions for a search prefix
    ///
    /// - Parameters:
    ///   - prefix: The prefix to match (searches code and city)
    ///   - limit: Maximum number of suggestions to return (default: 10)
    /// - Returns: Array of matching area codes, limited to the specified count
    /// - Throws: `AreaCodeError` if data cannot be loaded
    public func suggestions(for prefix: String, limit: Int = 10) async throws -> [AreaCode] {
        let allCodes = try await getAllCodes()
        let lowercasePrefix = prefix.lowercased()
        
        return Array(allCodes.filter {
            $0.code.hasPrefix(prefix) ||
            $0.city.lowercased().hasPrefix(lowercasePrefix)
        }.prefix(limit))
    }
    
    /// Get all unique countries available in the dataset
    ///
    /// - Returns: Array of unique ISO 3166-1 alpha-2 country codes (sorted)
    /// - Throws: `AreaCodeError` if data cannot be loaded
    public func availableCountries() async throws -> [String] {
        let allCodes = try await getAllCodes()
        return Array(Set(allCodes.map { $0.country })).sorted()
    }
    
    /// Clear all cached data
    ///
    /// Use this to free memory or force a reload of data
    public func clearCache() {
        allCodesCache = nil
        countryCache.removeAll()
        e164Index = nil
        maxE164Length = 0
        loadTask?.cancel()
        loadTask = nil
    }
    
    // MARK: - Private Index
    
    /// Builds (once) and returns the E.164 prefix index used by `lookup(e164:)`,
    /// `lookupLongestPrefix(e164:minLength:)`, and `resolve(fullE164:)`.
    /// On duplicate e164 keys, the first entry in load order wins.
    private func getE164Index() async throws -> [String: AreaCode] {
        if let index = e164Index {
            return index
        }
        
        let allCodes = try await getAllCodes()
        var index: [String: AreaCode] = [:]
        index.reserveCapacity(allCodes.count)
        for areaCode in allCodes where index[areaCode.e164] == nil {
            index[areaCode.e164] = areaCode
        }
        
        e164Index = index
        maxE164Length = index.keys.map(\.count).max() ?? 0
        return index
    }
    
    // MARK: - Private Loading Methods
    
    /// Load all area code files from the bundle
    private func loadAllFiles() async throws -> [AreaCode] {
        let bundle = Bundle.module
        
        guard let urls = bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) else {
            throw AreaCodeError.noFilesFound
        }
        
        // Load files concurrently for better performance
        return try await withThrowingTaskGroup(of: (String, [AreaCode]).self) { group in
            for url in urls {
                group.addTask {
                    let fileName = url.lastPathComponent
                    do {
                        let data = try Data(contentsOf: url)
                        let codes = try JSONDecoder().decode([AreaCode].self, from: data)
                        return (fileName, codes)
                    } catch let error as DecodingError {
                        throw AreaCodeError.decodingFailed("\(fileName): \(error.localizedDescription)")
                    } catch {
                        throw AreaCodeError.invalidData("\(fileName): \(error.localizedDescription)")
                    }
                }
            }
            
            var allCodes: [AreaCode] = []
            for try await (fileName, codes) in group {
                allCodes.append(contentsOf: codes)
                #if DEBUG
                print("GlobalPhoneAreaCodeKit: Loaded \(codes.count) codes from \(fileName)")
                #endif
            }
            
            return allCodes
        }
    }
    
    /// Load a specific country's area code file
    private func loadFile(countryCode: String) async throws -> [AreaCode] {
        let bundle = Bundle.module
        let fileName = "\(countryCode.uppercased())-codes"
        
        guard let url = bundle.url(forResource: fileName, withExtension: "json") else {
            throw AreaCodeError.fileNotFound(countryCode)
        }
        
        do {
            let data = try Data(contentsOf: url)
            let codes = try JSONDecoder().decode([AreaCode].self, from: data)
            
            #if DEBUG
            print("GlobalPhoneAreaCodeKit: Loaded \(codes.count) codes for \(countryCode)")
            #endif
            
            return codes
        } catch let error as DecodingError {
            throw AreaCodeError.decodingFailed("\(fileName): \(error.localizedDescription)")
        } catch {
            throw AreaCodeError.invalidData("\(fileName): \(error.localizedDescription)")
        }
    }
}
