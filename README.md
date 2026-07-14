# GlobalPhoneAreaCodeKit

A Swift Package for querying global phone area codes, identifying regions, and resolving location data from phone numbers.

This library parses comprehensive CSV data into an easy-to-use Swift API, allowing you to look up area codes, search for cities, and filter by country.

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/GlobalPhoneAreaCodes/GlobalPhoneAreaCodeKit.git", from: "1.0.0")
]
```

## Usage

### Basic Examples

```swift
import GlobalPhoneAreaCodeKit

// All methods are async - use within an async context
Task {
    // 1. Lookup specific area code
    // Note: Same area code can exist in multiple countries!
    let codes = try await GlobalPhoneAreaCodeKit.shared.lookup(code: "212")
    // Returns both US (E.164: 1212) and Belarus (E.164: 375212)
    
    for code in codes {
        print("\(code.displayName) - E.164: +\(code.e164)")
    }
    
    // 1b. For unambiguous lookup, use E.164 format (includes country code)
    if let usCode = try await GlobalPhoneAreaCodeKit.shared.lookup(e164: "1212") {
        print(usCode.region)       // "North Jersey"
        print(usCode.city)         // "Jersey City"
        print(usCode.flag)         // "🇺🇸"
        print(usCode.countryName)  // "United States"
        print(usCode.displayName)  // "🇺🇸 212 - Jersey City"
    }
    
    // 2. Search by text (City, Region, or Notes)
    let results = try await GlobalPhoneAreaCodeKit.shared.search("Paris")
    // Returns entries for Paris, France, etc.
    
    // 3. Filter by Country
    let canadianCodes = try await GlobalPhoneAreaCodeKit.shared.codes(forCountry: "CA")
    print("Canada has \(canadianCodes.count) area codes")
    
    // 4. Get autocomplete suggestions
    let suggestions = try await GlobalPhoneAreaCodeKit.shared.suggestions(for: "41", limit: 5)
    
    // 5. Look up by E.164 format
    if let areaCode = try await GlobalPhoneAreaCodeKit.shared.lookup(e164: "1212") {
        print(areaCode.displayName)
    }
    
    // 6. Format phone numbers
    if let nyc = codes.first {
        let formatted = nyc.formatPhoneNumber("5551234")
        print(formatted) // "+12125551234"
    }
    
    // 7. Resolve a full phone number (longest-prefix match)
    // Any formatting is accepted - digits are extracted automatically
    if let resolved = try await GlobalPhoneAreaCodeKit.shared.resolve(fullE164: "+1 (212) 555-1234") {
        print(resolved.code)      // "212"
        print(resolved.country)   // "US" (ISO 3166-1 alpha-2)
        print(resolved.latitude ?? 0)   // 40.71427 (US codes have centroids)
        print(resolved.longitude ?? 0)  // -74.00597
    }
}
```

### SwiftUI Example

```swift
import SwiftUI
import GlobalPhoneAreaCodeKit

struct AreaCodeSearchView: View {
    @State private var searchText = ""
    @State private var results: [AreaCode] = []
    
    var body: some View {
        List(results) { areaCode in
            VStack(alignment: .leading) {
                Text(areaCode.displayName)
                    .font(.headline)
                Text(areaCode.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .searchable(text: $searchText)
        .onChange(of: searchText) { oldValue, newValue in
            Task {
                results = try await GlobalPhoneAreaCodeKit.shared.search(newValue)
            }
        }
    }
}
```

## Features

- ✅ **Thread-Safe**: Built with Swift actors for safe concurrent access
- ✅ **Async/Await**: Modern Swift concurrency support
- ✅ **Lazy Loading**: Data loaded on-demand with intelligent caching
- ✅ **Fast Performance**: Concurrent file loading and country-specific caching
- ✅ **Zero Dependencies**: Pure Swift with no external dependencies
- ✅ **Comprehensive Data**: Coverage for 60+ countries/regions
- ✅ **Type-Safe**: Codable, Sendable, and Hashable conformance
- ✅ **SwiftUI Ready**: Built-in display helpers and Identifiable conformance
- ✅ **E.164 Format**: Unambiguous phone number identification with country codes
- ✅ **Full-Number Resolution**: `resolve(fullE164:)` longest-prefix matches complete phone numbers in any formatting
- ✅ **Strict ISO 3166-1 alpha-2**: `country` is always an ISO code (`GB`, not `UK`); `UK`/`USA` accepted as input aliases
- ✅ **Localized Names**: Country names derived via `Locale`, following the user's language
- ✅ **Coordinates**: Optional centroid `latitude`/`longitude` (currently populated for US area codes)

## Supported Countries / Regions

The library currently includes data for the following:

| Code | Country |
|------|---------|
| AD | Andorra 🇦🇩 |
| AL | Albania 🇦🇱 |
| AT | Austria 🇦🇹 |
| BA | Bosnia and Herzegovina 🇧🇦 |
| BE | Belgium 🇧🇪 |
| BG | Bulgaria 🇧🇬 |
| BR | Brazil 🇧🇷 |
| BY | Belarus 🇧🇾 |
| CA | Canada 🇨🇦 |
| CH | Switzerland 🇨🇭 |
| CZ | Czech Republic 🇨🇿 |
| DE | Germany 🇩🇪 |
| FR | France 🇫🇷 |
| GB | United Kingdom 🇬🇧 |
| GG | Guernsey 🇬🇬 |
| GI | Gibraltar 🇬🇮 |
| GR | Greece 🇬🇷 |
| HR | Croatia 🇭🇷 |
| HU | Hungary 🇭🇺 |
| MX | Mexico 🇲🇽 |
| US | United States 🇺🇸 |

## Migration Guide

If you're upgrading from a previous version with synchronous APIs, here's how to migrate:

### Before (Synchronous)
```swift
let codes = GlobalPhoneAreaCodeKit.shared.lookup(code: "212")
let results = GlobalPhoneAreaCodeKit.shared.search("Paris")
let canadianCodes = GlobalPhoneAreaCodeKit.shared.codes(forCountry: "CA")
```

### After (Async/Await)
```swift
// Wrap in async context
Task {
    let codes = try await GlobalPhoneAreaCodeKit.shared.lookup(code: "212")
    let results = try await GlobalPhoneAreaCodeKit.shared.search("Paris")
    let canadianCodes = try await GlobalPhoneAreaCodeKit.shared.codes(forCountry: "CA")
}

// Or in an async function
func loadData() async throws {
    let codes = try await GlobalPhoneAreaCodeKit.shared.lookup(code: "212")
    // ...
}
```

### Breaking Changes

1. **All methods are now async** - Add `await` to all method calls
2. **Methods now throw** - Add `try` and handle `AreaCodeError` cases
3. **Actor isolation** - `GlobalPhoneAreaCodeKit` is now an actor for thread safety
4. **No synchronous access** - `allCodes` property removed (use `getAllCodes()` instead)

### Benefits of Migration

- **Better Performance**: Lazy loading prevents blocking app launch
- **Thread Safety**: Actor isolation prevents race conditions
- **Better UX**: Non-blocking UI during data loads
- **Memory Efficient**: Load only what you need
- **Error Handling**: Proper error reporting with `AreaCodeError`

## API Reference

### Core Methods

- `getAllCodes() async throws -> [AreaCode]` - Get all area codes (lazy loaded)
- `resolve(fullE164: String) async throws -> AreaCode?` - Resolve a full phone number via longest-prefix match (handles `+`, spaces, dashes, `00` prefix)
- `lookup(code: String) async throws -> [AreaCode]` - Find by area code
- `lookup(e164: String) async throws -> AreaCode?` - Find by exact E.164 prefix
- `search(_ query: String) async throws -> [AreaCode]` - Search by text
- `codes(forCountry: String) async throws -> [AreaCode]` - Filter by ISO country code (`UK`/`USA` aliases accepted)
- `suggestions(for: String, limit: Int) async throws -> [AreaCode]` - Autocomplete
- `availableCountries() async throws -> [String]` - List all ISO 3166-1 alpha-2 country codes
- `clearCache()` - Clear cached data

### Static Helpers

- `AreaCode.digitsOnly(_ input: String) -> String` - Strip all non-digit characters from a phone number
- `AreaCode.normalizeCountryCode(_ raw: String) -> String` - Normalize to ISO 3166-1 alpha-2 (`UK` → `GB`, `USA` → `US`)

### Error Types

The library throws `AreaCodeError` with these cases:
- `.fileNotFound(String)` - Country data file not found
- `.noFilesFound` - No JSON files in bundle
- `.invalidData(String)` - Malformed JSON data
- `.decodingFailed(String)` - JSON decoding error

### AreaCode Properties

- `code: String` - The area code number
- `country: String` - ISO 3166-1 alpha-2 country code (authoritative; e.g. `GB`, never `UK`)
- `region: String` - State/province/region
- `city: String` - Primary city
- `e164: String` - E.164 format number
- `notes: String` - Additional information
- `latitude: Double?` - Approximate centroid latitude (currently US only; nil elsewhere)
- `longitude: Double?` - Approximate centroid longitude (currently US only; nil elsewhere)
- `flag: String` - Country flag emoji
- `countryName: String` - Localized country name derived via `Locale` from the ISO code
- `displayName: String` - Formatted display string
- `subtitle: String` - Location detail string

## Understanding E.164 Format

**Important:** Area codes are NOT globally unique! For example, area code "212" exists in:
- **United States:** E.164 format `1212` (country code +1)
- **Belarus:** E.164 format `375212` (country code +375)

The E.164 format includes the country calling code, making it globally unique:

```swift
// Ambiguous - returns multiple results
let results = try await kit.lookup(code: "212")
// Returns both US and Belarus entries

// Unambiguous - returns exact match
let usCode = try await kit.lookup(e164: "1212")      // US only
let byCode = try await kit.lookup(e164: "375212")    // Belarus only

// Or resolve a complete phone number directly
let resolved = try await kit.resolve(fullE164: "+375 212 123456") // Belarus 212
```

**Best Practice:** Use E.164 format when you need to identify a specific phone number region globally. For raw user input or full phone numbers, use `resolve(fullE164:)` - it strips formatting and picks the longest matching prefix for you.


## Data Sources & Origin

This repository started as a collection of CSVs to map phone numbers to locations. It addresses the difficulty of finding accurate, free area code data compared to zip codes.

- **US**: NANPA (North American Numbering Plan)
- **Canada**: CNAC (Canadian Numbering Administrator)
- **Geolocation**: Geonames
- **European/Other**: Compiled from public numbering plans.

## License

You are free to use this compilation for any purpose (commercial or not).
