import XCTest
@testable import GlobalPhoneAreaCodeKit

final class GlobalPhoneAreaCodeKitTests: XCTestCase {
    
    // MARK: - Lookup Tests
    
    func testLookupValidCode() async throws {
        // Area code "212" exists in multiple countries with different E.164 formats
        let results = try await GlobalPhoneAreaCodeKit.shared.lookup(code: "212")
        XCTAssertGreaterThan(results.count, 0, "Should find at least one result for code 212")
        
        // Verify we can find both US and BY entries
        let usEntry = results.first(where: { $0.country.uppercased() == "US" })
        let byEntry = results.first(where: { $0.country.uppercased() == "BY" })
        
        // US: 212 has E.164 "1212" (country code 1)
        if let us = usEntry {
            XCTAssertEqual(us.code, "212")
            XCTAssertEqual(us.e164, "1212", "US area code 212 should have E.164 format 1212")
            XCTAssertFalse(us.region.isEmpty)
        }
        
        // Belarus: 212 has E.164 "375212" (country code 375)
        if let by = byEntry {
            XCTAssertEqual(by.code, "212")
            XCTAssertEqual(by.e164, "375212", "Belarus area code 212 should have E.164 format 375212")
        }
        
        // This demonstrates why E.164 lookup is unambiguous
        XCTAssertNotEqual(usEntry?.e164, byEntry?.e164, "Same area code in different countries should have different E.164 formats")
    }
    
    func testLookupInvalidCode() async throws {
        let results = try await GlobalPhoneAreaCodeKit.shared.lookup(code: "999999")
        XCTAssertTrue(results.isEmpty, "Should not find results for invalid code")
    }
    
    func testLookupE164Format() async throws {
        // E.164 format is unambiguous - includes country calling code
        
        // US: Area code 212 = E.164 "1212" (country code 1)
        let usResult = try await GlobalPhoneAreaCodeKit.shared.lookup(e164: "1212")
        XCTAssertNotNil(usResult, "Should find US area code with E.164 1212")
        
        if let us = usResult {
            XCTAssertEqual(us.e164, "1212")
            XCTAssertEqual(us.code, "212")
            XCTAssertEqual(us.country.uppercased(), "US", "E.164 1212 is US, not Belarus")
        }
        
        // Belarus: Area code 212 = E.164 "375212" (country code 375)
        let byResult = try await GlobalPhoneAreaCodeKit.shared.lookup(e164: "375212")
        XCTAssertNotNil(byResult, "Should find Belarus area code with E.164 375212")
        
        if let by = byResult {
            XCTAssertEqual(by.e164, "375212")
            XCTAssertEqual(by.code, "212")
            XCTAssertEqual(by.country.uppercased(), "BY", "E.164 375212 is Belarus, not US")
        }
        
        // Both have area code "212" but completely different E.164 formats
        XCTAssertNotEqual(usResult?.e164, byResult?.e164)
        XCTAssertEqual(usResult?.code, byResult?.code)
    }
    
    func testLookupInvalidE164() async throws {
        let result = try await GlobalPhoneAreaCodeKit.shared.lookup(e164: "999999")
        XCTAssertNil(result, "Should not find invalid E.164")
    }
    
    // MARK: - Search Tests
    
    func testSearchByCity() async throws {
        let results = try await GlobalPhoneAreaCodeKit.shared.search("New York")
        XCTAssertFalse(results.isEmpty, "Should find results for New York")
        
        let hasNewYork = results.contains { areaCode in
            areaCode.city.localizedCaseInsensitiveContains("New York") ||
            areaCode.region.localizedCaseInsensitiveContains("New York")
        }
        XCTAssertTrue(hasNewYork, "Results should contain New York entries")
    }
    
    func testSearchByRegion() async throws {
        let results = try await GlobalPhoneAreaCodeKit.shared.search("California")
        XCTAssertFalse(results.isEmpty, "Should find results for California")
    }
    
    func testSearchCaseInsensitive() async throws {
        let lowercaseResults = try await GlobalPhoneAreaCodeKit.shared.search("seattle")
        let uppercaseResults = try await GlobalPhoneAreaCodeKit.shared.search("SEATTLE")
        
        XCTAssertEqual(lowercaseResults.count, uppercaseResults.count,
                      "Search should be case insensitive")
    }
    
    func testSearchEmptyQuery() async throws {
        let results = try await GlobalPhoneAreaCodeKit.shared.search("")
        XCTAssertTrue(results.isEmpty, "Empty search should return empty results")
    }
    
    // MARK: - Country Filter Tests
    
    func testCodesForUS() async throws {
        let usCodes = try await GlobalPhoneAreaCodeKit.shared.codes(forCountry: "US")
        XCTAssertFalse(usCodes.isEmpty, "Should find US area codes")
        
        for code in usCodes {
            XCTAssertEqual(code.country.uppercased(), "US")
        }
    }
    
    func testCodesForCanada() async throws {
        let caCodes = try await GlobalPhoneAreaCodeKit.shared.codes(forCountry: "CA")
        XCTAssertFalse(caCodes.isEmpty, "Should find Canadian area codes")
        
        for code in caCodes {
            XCTAssertEqual(code.country.uppercased(), "CA")
        }
    }
    
    func testCodesForInvalidCountry() async throws {
        do {
            let codes = try await GlobalPhoneAreaCodeKit.shared.codes(forCountry: "INVALID")
            XCTAssertTrue(codes.isEmpty, "Should return empty array for invalid country")
        } catch AreaCodeError.fileNotFound {
            // This is also acceptable - file doesn't exist
        }
    }
    
    // MARK: - Suggestions Tests
    
    func testSuggestions() async throws {
        let suggestions = try await GlobalPhoneAreaCodeKit.shared.suggestions(for: "41", limit: 5)
        XCTAssertTrue(suggestions.count <= 5, "Should respect limit")
        
        for suggestion in suggestions {
            let matches = suggestion.code.hasPrefix("41") ||
                         suggestion.city.lowercased().hasPrefix("41")
            XCTAssertTrue(matches, "Suggestion should match prefix")
        }
    }
    
    func testSuggestionsLimit() async throws {
        let limited = try await GlobalPhoneAreaCodeKit.shared.suggestions(for: "2", limit: 3)
        XCTAssertTrue(limited.count <= 3, "Should not exceed limit")
        
        let unlimited = try await GlobalPhoneAreaCodeKit.shared.suggestions(for: "2", limit: 100)
        XCTAssertTrue(unlimited.count >= limited.count, "Higher limit should return more results")
    }
    
    // MARK: - Available Countries Tests
    
    func testAvailableCountries() async throws {
        let countries = try await GlobalPhoneAreaCodeKit.shared.availableCountries()
        XCTAssertFalse(countries.isEmpty, "Should have available countries")
        
        // Check for known countries
        let countriesUpper = countries.map { $0.uppercased() }
        XCTAssertTrue(countriesUpper.contains("US"), "Should include US")
        XCTAssertTrue(countriesUpper.contains("CA"), "Should include CA")
        
        // Should be unique
        let uniqueCountries = Set(countries)
        XCTAssertEqual(countries.count, uniqueCountries.count, "Countries should be unique")
    }
    
    // MARK: - Data Loading Tests
    
    func testGetAllCodes() async throws {
        let allCodes = try await GlobalPhoneAreaCodeKit.shared.getAllCodes()
        XCTAssertFalse(allCodes.isEmpty, "Should load area codes")
        XCTAssertGreaterThan(allCodes.count, 100, "Should have substantial data")
    }
    
    func testCaching() async throws {
        // Clear cache first to ensure clean test
        await GlobalPhoneAreaCodeKit.shared.clearCache()
        
        // First load (from disk)
        let start1 = Date()
        let codes1 = try await GlobalPhoneAreaCodeKit.shared.getAllCodes()
        let duration1 = Date().timeIntervalSince(start1)
        
        // Second load (should be cached in memory)
        let start2 = Date()
        let codes2 = try await GlobalPhoneAreaCodeKit.shared.getAllCodes()
        let duration2 = Date().timeIntervalSince(start2)
        
        XCTAssertEqual(codes1.count, codes2.count, "Should return same data")
        
        // Cached load should be much faster (at least 50% faster)
        // Only assert if first load took measurable time
        if duration1 > 0.001 {
            XCTAssertLessThan(duration2, duration1 * 0.5, "Cached load should be at least 50% faster")
        }
    }
    
    func testClearCache() async throws {
        // Load data
        _ = try await GlobalPhoneAreaCodeKit.shared.getAllCodes()
        
        // Clear cache
        await GlobalPhoneAreaCodeKit.shared.clearCache()
        
        // Load again (should work)
        let codes = try await GlobalPhoneAreaCodeKit.shared.getAllCodes()
        XCTAssertFalse(codes.isEmpty, "Should reload after cache clear")
    }
    
    // MARK: - AreaCode Model Tests
    
    func testAreaCodeProperties() async throws {
        let codes = try await GlobalPhoneAreaCodeKit.shared.lookup(code: "212")
        guard let areaCode = codes.first else {
            XCTFail("Should find area code 212")
            return
        }
        
        // Test basic properties
        XCTAssertFalse(areaCode.code.isEmpty)
        XCTAssertFalse(areaCode.country.isEmpty)
        XCTAssertFalse(areaCode.region.isEmpty)
        XCTAssertFalse(areaCode.e164.isEmpty)
        
        // Test computed properties
        XCTAssertFalse(areaCode.flag.isEmpty)
        XCTAssertFalse(areaCode.countryName.isEmpty)
        XCTAssertFalse(areaCode.displayName.isEmpty)
        XCTAssertFalse(areaCode.subtitle.isEmpty)
        
        // Test flag is emoji
        XCTAssertTrue(areaCode.flag.unicodeScalars.allSatisfy { $0.properties.isEmoji })
    }
    
    func testFormatPhoneNumber() async throws {
        let codes = try await GlobalPhoneAreaCodeKit.shared.lookup(code: "212")
        guard let areaCode = codes.first else {
            XCTFail("Should find area code 212")
            return
        }
        
        let formatted = areaCode.formatPhoneNumber("5551234")
        XCTAssertTrue(formatted.hasPrefix("+"), "Should start with +")
        XCTAssertTrue(formatted.contains("212"), "Should contain area code")
        XCTAssertTrue(formatted.hasSuffix("5551234"), "Should end with local number")
    }
    
    func testAreaCodeHashable() async throws {
        let codes = try await GlobalPhoneAreaCodeKit.shared.lookup(code: "212")
        guard let code1 = codes.first else {
            XCTFail("Should find area code 212")
            return
        }
        
        // Create a set to test Hashable
        var set = Set<AreaCode>()
        set.insert(code1)
        XCTAssertEqual(set.count, 1)
        
        // Insert same code again
        set.insert(code1)
        XCTAssertEqual(set.count, 1, "Should not insert duplicate")
    }
    
    func testAreaCodeIdentifiable() async throws {
        let codes = try await GlobalPhoneAreaCodeKit.shared.lookup(code: "212")
        guard let areaCode = codes.first else {
            XCTFail("Should find area code 212")
            return
        }
        
        XCTAssertEqual(areaCode.id, areaCode.e164, "ID should equal E.164")
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorLocalization() {
        let error1 = AreaCodeError.fileNotFound("XX")
        XCTAssertNotNil(error1.errorDescription)
        XCTAssertTrue(error1.errorDescription!.contains("XX"))
        
        let error2 = AreaCodeError.noFilesFound
        XCTAssertNotNil(error2.errorDescription)
        
        let error3 = AreaCodeError.invalidData("test reason")
        XCTAssertNotNil(error3.errorDescription)
        XCTAssertTrue(error3.errorDescription!.contains("test reason"))
        
        let error4 = AreaCodeError.decodingFailed("test reason")
        XCTAssertNotNil(error4.errorDescription)
        XCTAssertTrue(error4.errorDescription!.contains("test reason"))
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentAccess() async throws {
        // Test that multiple concurrent requests work correctly (actor isolation)
        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 1...10 {
                group.addTask {
                    let codes = try await GlobalPhoneAreaCodeKit.shared.lookup(code: "212")
                    XCTAssertFalse(codes.isEmpty, "Request \(i) should succeed")
                }
            }
            
            try await group.waitForAll()
        }
    }
    
    func testParallelCountryLoads() async throws {
        async let us = GlobalPhoneAreaCodeKit.shared.codes(forCountry: "US")
        async let ca = GlobalPhoneAreaCodeKit.shared.codes(forCountry: "CA")
        async let gb = GlobalPhoneAreaCodeKit.shared.codes(forCountry: "GB")
        
        let (usCodes, caCodes, gbCodes) = try await (us, ca, gb)
        
        XCTAssertFalse(usCodes.isEmpty, "US codes should load")
        XCTAssertFalse(caCodes.isEmpty, "CA codes should load")
        XCTAssertFalse(gbCodes.isEmpty, "GB codes should load")
    }
    
    // MARK: - Performance Tests
    
    func testLoadingPerformance() async throws {
        measure {
            let expectation = XCTestExpectation(description: "Load all codes")
            
            Task {
                _ = try await GlobalPhoneAreaCodeKit.shared.getAllCodes()
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    func testSearchPerformance() async throws {
        // Preload data
        _ = try await GlobalPhoneAreaCodeKit.shared.getAllCodes()
        
        measure {
            let expectation = XCTestExpectation(description: "Search")
            
            Task {
                _ = try await GlobalPhoneAreaCodeKit.shared.search("New York")
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 1.0)
        }
    }
}

