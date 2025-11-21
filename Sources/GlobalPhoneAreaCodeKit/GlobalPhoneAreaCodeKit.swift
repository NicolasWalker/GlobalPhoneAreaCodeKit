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
    public let country: String
    public let region: String
    public let city: String
    public let e164: String
    public let notes: String
    
    /// Returns the country's flag emoji
    public var flag: String {
        countryCodeToFlag(country)
    }
    
    /// Returns the full country name when available
    public var countryName: String {
        switch country.uppercased() {
        case "US", "USA": return "United States"
        case "CA": return "Canada"
        case "GB", "UK": return "United Kingdom"
        case "DE": return "Germany"
        case "FR": return "France"
        case "BR": return "Brazil"
        case "MX": return "Mexico"
        case "AD": return "Andorra"
        case "AG": return "Antigua and Barbuda"
        case "AL": return "Albania"
        case "AT": return "Austria"
        case "BA": return "Bosnia and Herzegovina"
        case "BB": return "Barbados"
        case "BE": return "Belgium"
        case "BG": return "Bulgaria"
        case "BS": return "Bahamas"
        case "BY": return "Belarus"
        case "BZ": return "Belize"
        case "CH": return "Switzerland"
        case "CR": return "Costa Rica"
        case "CU": return "Cuba"
        case "CY": return "Cyprus"
        case "CZ": return "Czech Republic"
        case "DK": return "Denmark"
        case "EE": return "Estonia"
        case "ES": return "Spain"
        case "FI": return "Finland"
        case "GG": return "Guernsey"
        case "GI": return "Gibraltar"
        case "GR": return "Greece"
        case "HR": return "Croatia"
        case "HU": return "Hungary"
        case "IE": return "Ireland"
        case "IM": return "Isle of Man"
        case "IS": return "Iceland"
        case "IT": return "Italy"
        case "JE": return "Jersey"
        case "LI": return "Liechtenstein"
        case "LT": return "Lithuania"
        case "LU": return "Luxembourg"
        case "LV": return "Latvia"
        case "MC": return "Monaco"
        case "MD": return "Moldova"
        case "ME": return "Montenegro"
        case "MK": return "North Macedonia"
        case "MT": return "Malta"
        case "NL": return "Netherlands"
        case "NO": return "Norway"
        case "PL": return "Poland"
        case "PT": return "Portugal"
        case "RO": return "Romania"
        case "RS": return "Serbia"
        case "RU": return "Russia"
        case "SE": return "Sweden"
        case "SI": return "Slovenia"
        case "SK": return "Slovakia"
        case "SM": return "San Marino"
        case "UA": return "Ukraine"
        case "VA": return "Vatican City"
        default: return country
        }
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
        let code = countryCode.uppercased()
        
        // Handle special cases
        guard code.count == 2 else {
            if code == "UK" { return "🇬🇧" }
            if code == "USA" { return "🇺🇸" }
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
    /// - Parameter code: The area code to search for (e.g., "212", "416")
    /// - Returns: Array of matching area codes (multiple entries for overlapping codes)
    /// - Throws: `AreaCodeError` if data cannot be loaded
    public func lookup(code: String) async throws -> [AreaCode] {
        let allCodes = try await getAllCodes()
        return allCodes.filter { $0.code == code }
    }
    
    /// Look up an area code by E.164 format
    ///
    /// - Parameter e164: The E.164 number to search for (e.g., "1212")
    /// - Returns: The matching area code, or nil if not found
    /// - Throws: `AreaCodeError` if data cannot be loaded
    public func lookup(e164: String) async throws -> AreaCode? {
        let allCodes = try await getAllCodes()
        return allCodes.first { $0.e164 == e164 }
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
    ///
    /// - Parameter country: Country code (e.g., "US", "CA") or name
    /// - Returns: Array of area codes for the specified country
    /// - Throws: `AreaCodeError` if data cannot be loaded
    public func codes(forCountry country: String) async throws -> [AreaCode] {
        let normalizedCountry = country.uppercased()
        
        // Check cache first
        if let cached = countryCache[normalizedCountry] {
            return cached
        }
        
        // Try loading specific country file first (more efficient)
        if let countryCodes = try? await loadFile(countryCode: normalizedCountry) {
            countryCache[normalizedCountry] = countryCodes
            return countryCodes
        }
        
        // Fall back to filtering all codes (for country name searches)
        let allCodes = try await getAllCodes()
        let filtered = allCodes.filter { 
            $0.country.localizedCaseInsensitiveContains(country) 
        }
        
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
    /// - Returns: Array of unique country codes (sorted)
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
        loadTask?.cancel()
        loadTask = nil
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
