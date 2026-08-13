# Changelog

## 1.2.0

### Added

- `lookupLongestPrefix(e164:minLength:)` — dictionary-backed longest-prefix match on the shared E.164 index. Truncates to the dataset’s max key length (derived at load time). **`minLength` is exclusive**: candidates with length ≤ `minLength` are not tested (pass the country calling code’s digit count).

### Changed

- `lookup(e164:)` now uses the same first-wins E.164 dictionary as `resolve(fullE164:)` (O(1) instead of a linear scan). Observable first-match behavior is unchanged.
- `clearCache()` continues to invalidate the shared index so the next lookup rebuilds it.
