# Understanding E.164 Format

## The Problem: Area Codes Are NOT Globally Unique

Many developers assume area codes uniquely identify a location. **This is incorrect!**

### Real Example: Area Code 212

Area code "212" exists in **multiple countries**:

| Country | Area Code | Country Code | E.164 Format | Location |
|---------|-----------|--------------|--------------|----------|
| 🇺🇸 United States | 212 | +1 | **1212** | New York City area |
| 🇧🇾 Belarus | 212 | +375 | **375212** | Vitebsk region |

Both have area code "212", but they're completely different phone number regions!

---

## The Solution: E.164 Format

**E.164** is the international standard for telephone numbers that includes:
1. **Country calling code** (e.g., 1 for US, 375 for Belarus)
2. **Area/city code** (e.g., 212)
3. **Subscriber number**

Format: `+[Country Code][Area Code][Subscriber Number]`

### Why E.164 Matters

E.164 format is **globally unique** because it includes the country code:
- US 212: `+1-212-555-1234` → E.164 prefix `1212`
- Belarus 212: `+375-212-555-1234` → E.164 prefix `375212`

---

## Using This Library Correctly

### ❌ Ambiguous Lookup (Returns Multiple Results)

```swift
// Looking up just the area code
let results = try await GlobalPhoneAreaCodeKit.shared.lookup(code: "212")

// This returns BOTH:
// - US entry (E.164: 1212)
// - Belarus entry (E.164: 375212)

print("Found \(results.count) results")  // Output: 2
```

**Problem:** Which "212" did you mean? You have to filter by country manually.

### ✅ Unambiguous Lookup (Exact Match)

```swift
// Looking up with E.164 format
let usCode = try await GlobalPhoneAreaCodeKit.shared.lookup(e164: "1212")
// Returns ONLY US entry

let byCode = try await GlobalPhoneAreaCodeKit.shared.lookup(e164: "375212")
// Returns ONLY Belarus entry
```

**Benefit:** Globally unique identifier, no ambiguity!

---

## When to Use Each Method

### Use `lookup(code:)` when:
- Searching by area code alone
- Want to see all countries that share an area code
- Building a search interface
- Don't know the country yet

```swift
// Show user all possible matches
let matches = try await kit.lookup(code: "212")
for match in matches {
    print("\(match.countryName): \(match.displayName)")
}
```

### Use `lookup(e164:)` when:
- You have a complete phone number
- Need to identify a specific region globally
- Working with international phone numbers
- Storing/retrieving phone number metadata

```swift
// Parse full phone number
let phoneNumber = "+1-212-555-1234"
let e164Prefix = extractE164Prefix(phoneNumber)  // "1212"
let code = try await kit.lookup(e164: e164Prefix)
```

---

## More Examples of Overlapping Area Codes

Area code "212" isn't unique! Here are other examples:

| Area Code | Countries with This Code |
|-----------|--------------------------|
| 212 | US (🇺🇸), Belarus (🇧🇾) |
| 20 | Multiple European countries |
| 44 | Multiple regions in UK system |

**Key Insight:** Always use E.164 format for international phone systems!

---

## Best Practices

### ✅ DO

```swift
// Store E.164 format in your database
struct Contact {
    let name: String
    let e164: String  // "1212" or "375212"
}

// Look up by E.164 for accuracy
let code = try await kit.lookup(e164: contact.e164)
```

### ❌ DON'T

```swift
// Store just area code (ambiguous!)
struct Contact {
    let name: String
    let areaCode: String  // "212" - which country?
}

// Have to guess or filter manually
let codes = try await kit.lookup(code: contact.areaCode)
let usCode = codes.first { $0.country == "US" }  // Manual filtering
```

---

## Complete Working Example

```swift
import GlobalPhoneAreaCodeKit

func processPhoneNumber(_ fullNumber: String) async throws {
    // Example: "+1-212-555-1234"
    
    // Extract components
    let components = parsePhoneNumber(fullNumber)
    // components.countryCode = "1"
    // components.areaCode = "212"
    // components.e164Prefix = "1212"
    
    // Option 1: Ambiguous lookup
    let allMatches = try await GlobalPhoneAreaCodeKit.shared.lookup(
        code: components.areaCode
    )
    print("Found \(allMatches.count) regions with area code \(components.areaCode)")
    
    // Option 2: Precise lookup (RECOMMENDED)
    if let exactCode = try await GlobalPhoneAreaCodeKit.shared.lookup(
        e164: components.e164Prefix
    ) {
        print("This number is from: \(exactCode.displayName)")
        print("Location: \(exactCode.subtitle)")
        print("Country: \(exactCode.countryName) \(exactCode.flag)")
        
        // Now you know exactly which region this is!
        if exactCode.country == "US" {
            print("US phone number")
        } else if exactCode.country == "BY" {
            print("Belarus phone number")
        }
    }
}
```

---

## International Standard

E.164 is defined by the International Telecommunication Union (ITU):
- **Maximum length:** 15 digits
- **Format:** +[Country Code][National Number]
- **Used by:** All international phone systems, WhatsApp, Signal, etc.

### Resources
- [ITU E.164 Standard](https://www.itu.int/rec/T-REC-E.164/)
- [Wikipedia: E.164](https://en.wikipedia.org/wiki/E.164)

---

## Summary

| Aspect | Area Code Only | E.164 Format |
|--------|---------------|--------------|
| **Uniqueness** | ❌ Not unique | ✅ Globally unique |
| **Identifies Country** | ❌ No | ✅ Yes |
| **International Use** | ❌ Ambiguous | ✅ Standard |
| **Recommended For** | Search/exploration | Production systems |

**Golden Rule:** When precision matters, always use E.164 format!

---

## Questions?

### Q: How do I get the E.164 prefix from a phone number?

A: Concatenate the country code with the area code:
```swift
let countryCode = "1"        // US
let areaCode = "212"         // NYC
let e164Prefix = countryCode + areaCode  // "1212"
```

### Q: Can I convert between formats?

A: Yes! The `AreaCode` struct provides both:
```swift
if let code = try await kit.lookup(e164: "1212") {
    print(code.code)    // "212" (area code)
    print(code.e164)    // "1212" (full E.164 prefix)
}
```

### Q: Why doesn't the library just use area codes?

A: Because area codes alone don't identify a location globally. This library handles international phone numbers correctly by using E.164 format internally.

---

**Remember:** Area codes overlap between countries. E.164 format is your friend! 🌍📞

