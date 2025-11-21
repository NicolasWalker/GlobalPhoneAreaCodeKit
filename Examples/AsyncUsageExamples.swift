import Foundation
import GlobalPhoneAreaCodeKit

// MARK: - Example Usage of GlobalPhoneAreaCodeKit

/// This file demonstrates how to use the async/await API

// MARK: - Basic Lookup Examples

func lookupAreaCode() async {
    do {
        // IMPORTANT: Area codes are NOT globally unique!
        // The same area code can exist in multiple countries
        let results = try await GlobalPhoneAreaCodeKit.shared.lookup(code: "212")
        
        print("Area code 212 exists in \(results.count) countries:")
        for areaCode in results {
            print("\nCode: \(areaCode.code)")
            print("Location: \(areaCode.city.isEmpty ? areaCode.region : areaCode.city), \(areaCode.region)")
            print("Country: \(areaCode.countryName) \(areaCode.flag)")
            print("E.164: +\(areaCode.e164)")  // This is globally unique!
            print("Notes: \(areaCode.notes)")
        }
        
        // Output will show:
        // - US: area code 212, E.164 +1212 (country code 1)
        // - Belarus: area code 212, E.164 +375212 (country code 375)
        
    } catch {
        print("Error looking up area code: \(error.localizedDescription)")
    }
}

func lookupByE164() async {
    do {
        // E.164 format is UNAMBIGUOUS - includes country calling code
        // This is the recommended way to look up a specific area code
        
        // US area code 212 (country code 1)
        if let usCode = try await GlobalPhoneAreaCodeKit.shared.lookup(e164: "1212") {
            print("US: \(usCode.displayName)")
            print("    \(usCode.subtitle)")
            print("    E.164: +\(usCode.e164)")
        }
        
        // Belarus area code 212 (country code 375)
        if let byCode = try await GlobalPhoneAreaCodeKit.shared.lookup(e164: "375212") {
            print("\nBelarus: \(byCode.displayName)")
            print("         \(byCode.subtitle)")
            print("         E.164: +\(byCode.e164)")
        }
        
        // This demonstrates that the same area code "212" has completely
        // different meanings in different countries. E.164 format prevents ambiguity!
        
    } catch {
        print("Error: \(error.localizedDescription)")
    }
}

// MARK: - Search Examples

func searchByCity() async {
    do {
        // Search for all area codes in Paris
        let results = try await GlobalPhoneAreaCodeKit.shared.search("Paris")
        
        print("Found \(results.count) area codes matching 'Paris':")
        for areaCode in results {
            print("  \(areaCode.displayName)")
        }
    } catch {
        print("Error searching: \(error.localizedDescription)")
    }
}

func searchByRegion() async {
    do {
        // Search by state/region
        let results = try await GlobalPhoneAreaCodeKit.shared.search("California")
        
        print("California area codes:")
        for areaCode in results {
            print("  \(areaCode.code) - \(areaCode.city)")
        }
    } catch {
        print("Error: \(error.localizedDescription)")
    }
}

// MARK: - Country Filter Examples

func getCountryCodes() async {
    do {
        // Get all Canadian area codes
        let canadianCodes = try await GlobalPhoneAreaCodeKit.shared.codes(forCountry: "CA")
        
        print("Canada has \(canadianCodes.count) area codes:")
        for areaCode in canadianCodes.prefix(5) {
            print("  \(areaCode.code) - \(areaCode.region)")
        }
    } catch {
        print("Error: \(error.localizedDescription)")
    }
}

func getAllCountries() async {
    do {
        // Get list of all available countries
        let countries = try await GlobalPhoneAreaCodeKit.shared.availableCountries()
        
        print("Available countries: \(countries.joined(separator: ", "))")
    } catch {
        print("Error: \(error.localizedDescription)")
    }
}

// MARK: - Autocomplete Example

func autocompleteSuggestions() async {
    do {
        // Get autocomplete suggestions
        let suggestions = try await GlobalPhoneAreaCodeKit.shared.suggestions(for: "41", limit: 5)
        
        print("Suggestions for '41':")
        for suggestion in suggestions {
            print("  \(suggestion.displayName)")
        }
    } catch {
        print("Error: \(error.localizedDescription)")
    }
}

// MARK: - SwiftUI Integration Example

#if canImport(SwiftUI)
import SwiftUI

struct AreaCodeSearchView: View {
    @State private var searchText = ""
    @State private var results: [AreaCode] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Searching...")
                } else if let error = errorMessage {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                } else {
                    List(results) { areaCode in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(areaCode.displayName)
                                .font(.headline)
                            Text(areaCode.subtitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if !areaCode.notes.isEmpty {
                                Text(areaCode.notes)
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Area Code Search")
            .searchable(text: $searchText, prompt: "Search city, region, or code")
            .onChange(of: searchText) { oldValue, newValue in
                Task {
                    await performSearch(query: newValue)
                }
            }
            .task {
                // Preload data in background
                _ = try? await GlobalPhoneAreaCodeKit.shared.getAllCodes()
            }
        }
    }
    
    private func performSearch(query: String) async {
        guard !query.isEmpty else {
            results = []
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Try code lookup first
            var searchResults = try await GlobalPhoneAreaCodeKit.shared.lookup(code: query)
            
            // If no exact match, do text search
            if searchResults.isEmpty {
                searchResults = try await GlobalPhoneAreaCodeKit.shared.search(query)
            }
            
            results = searchResults
        } catch {
            errorMessage = error.localizedDescription
            results = []
        }
        
        isLoading = false
    }
}

// MARK: - Country Picker Example

struct CountryPickerView: View {
    @State private var countries: [String] = []
    @State private var selectedCountry: String?
    @State private var areaCodes: [AreaCode] = []
    
    var body: some View {
        NavigationView {
            List {
                Section("Countries") {
                    ForEach(countries, id: \.self) { country in
                        Button(country) {
                            selectedCountry = country
                            Task {
                                await loadCountryCodes(country)
                            }
                        }
                    }
                }
                
                if let country = selectedCountry {
                    Section("\(country) Area Codes") {
                        ForEach(areaCodes) { code in
                            VStack(alignment: .leading) {
                                Text(code.displayName)
                                    .font(.headline)
                                Text(code.subtitle)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Countries")
            .task {
                await loadCountries()
            }
        }
    }
    
    private func loadCountries() async {
        do {
            countries = try await GlobalPhoneAreaCodeKit.shared.availableCountries()
        } catch {
            print("Error loading countries: \(error)")
        }
    }
    
    private func loadCountryCodes(_ country: String) async {
        do {
            areaCodes = try await GlobalPhoneAreaCodeKit.shared.codes(forCountry: country)
        } catch {
            print("Error loading codes: \(error)")
        }
    }
}
#endif

// MARK: - Parallel Loading Example

func loadMultipleCountries() async {
    // Load multiple countries in parallel
    async let usCodes = GlobalPhoneAreaCodeKit.shared.codes(forCountry: "US")
    async let caCodes = GlobalPhoneAreaCodeKit.shared.codes(forCountry: "CA")
    async let gbCodes = GlobalPhoneAreaCodeKit.shared.codes(forCountry: "GB")
    
    do {
        let (us, ca, gb) = try await (usCodes, caCodes, gbCodes)
        print("US: \(us.count) codes")
        print("CA: \(ca.count) codes")
        print("GB: \(gb.count) codes")
    } catch {
        print("Error: \(error)")
    }
}

// MARK: - Memory Management Example

func clearCacheExample() async {
    do {
        // Load data
        let codes = try await GlobalPhoneAreaCodeKit.shared.getAllCodes()
        print("Loaded \(codes.count) codes")
        
        // Clear cache to free memory
        await GlobalPhoneAreaCodeKit.shared.clearCache()
        print("Cache cleared")
        
        // Next call will reload data
        let reloadedCodes = try await GlobalPhoneAreaCodeKit.shared.getAllCodes()
        print("Reloaded \(reloadedCodes.count) codes")
    } catch {
        print("Error: \(error)")
    }
}

// MARK: - Phone Number Formatting Example

func formatPhoneNumber() async {
    do {
        if let nyc = try await GlobalPhoneAreaCodeKit.shared.lookup(code: "212").first {
            let formatted = nyc.formatPhoneNumber("5551234")
            print("Formatted number: \(formatted)") // +12125551234
        }
    } catch {
        print("Error: \(error)")
    }
}

// MARK: - Error Handling Examples

func handleErrors() async {
    do {
        // This will throw if the file doesn't exist
        let codes = try await GlobalPhoneAreaCodeKit.shared.codes(forCountry: "XX")
        print("Found \(codes.count) codes")
    } catch AreaCodeError.fileNotFound(let country) {
        print("No data file found for country: \(country)")
    } catch AreaCodeError.noFilesFound {
        print("No area code data files found")
    } catch AreaCodeError.decodingFailed(let reason) {
        print("Failed to decode data: \(reason)")
    } catch {
        print("Unknown error: \(error)")
    }
}

