import Foundation

// MARK: - Data Model
public struct AreaCode: Codable, Identifiable {
    public var id: String { e164 }
    public let code: String
    public let country: String
    public let region: String
    public let city: String
    public let e164: String
    public let notes: String
    
    public var flag: String {
        switch country.lowercased() {
        case "us", "usa": return "🇺🇸"
        case "ca", "canada": return "🇨🇦"
        case "gb", "uk": return "🇬🇧"
        case "br", "brazil": return "🇧🇷"
        case "ad": return "🇦🇩"
        case "al": return "🇦🇱"
        case "at": return "🇦🇹"
        case "ba": return "🇧🇦"
        case "be": return "🇧🇪"
        case "bg": return "🇧🇬"
        case "by": return "🇧🇾"
        case "ch": return "🇨🇭"
        case "cz": return "🇨🇿"
        case "de": return "🇩🇪"
        case "fr": return "🇫🇷"
        case "gg": return "🇬🇬"
        case "gi": return "🇬🇮"
        case "gr": return "🇬🇷"
        case "hr": return "🇭🇷"
        case "hu": return "🇭🇺"
        case "mx": return "🇲🇽"
        default: return "🌍"
        }
    }
}

// MARK: - Library Logic
public class GlobalPhoneAreaCodeKit {
    
    public static let shared = GlobalPhoneAreaCodeKit()
    
    // This array will now hold the combined data from ALL files
    public private(set) var allCodes: [AreaCode] = []
    
    private init() {
        loadAllFiles()
    }
    
    private func loadAllFiles() {
        // 1. Find all JSON files in the Package Bundle
        let bundle = Bundle.module
        
        // Get URLs for every .json file in the resource path
        guard let urls = bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) else {
            print("GlobalPhoneAreaCodeKit: No JSON files found.")
            return
        }
        
        var combinedCodes: [AreaCode] = []
        let decoder = JSONDecoder()
        
        // 2. Loop through each file and decode it
        for url in urls {
            do {
                let data = try Data(contentsOf: url)
                let codesInFile = try decoder.decode([AreaCode].self, from: data)
                combinedCodes.append(contentsOf: codesInFile)
                print("Loaded \(codesInFile.count) codes from \(url.lastPathComponent)")
            } catch {
                print("Error loading file \(url.lastPathComponent): \(error)")
            }
        }
        
        // 3. Assign to the public property
        self.allCodes = combinedCodes
    }
    
    // MARK: - Public API (Same as before)
    
    public func lookup(code: String) -> [AreaCode] {
        return allCodes.filter { $0.code == code }
    }
    
    public func search(_ query: String) -> [AreaCode] {
        return allCodes.filter {
            $0.city.localizedCaseInsensitiveContains(query) ||
            $0.region.localizedCaseInsensitiveContains(query) ||
            $0.notes.localizedCaseInsensitiveContains(query)
        }
    }
    
    public func codes(forCountry country: String) -> [AreaCode] {
        return allCodes.filter { $0.country.localizedCaseInsensitiveContains(country) }
    }
}
