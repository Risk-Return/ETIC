import Foundation

/// A major world city with its longitude, used to help users pick a longitude
/// for true-solar-time correction without knowing the exact coordinate.
///
/// Longitudes are east-positive / west-negative. The list favors capitals and
/// large administrative centers across every continent.
struct WorldCity: Identifiable, Hashable {
    let name: String
    let region: String
    let longitude: Double

    var id: String { "\(region)/\(name)" }

    /// e.g. "116.4°E" / "74.0°W"
    var longitudeText: String {
        let hemisphere = longitude >= 0 ? "E" : "W"
        return String(format: "%.1f°%@", abs(longitude), hemisphere)
    }
}

/// Grouped catalog of world cities for the location picker.
enum WorldCities {
    struct Group: Identifiable {
        let name: String
        let cities: [WorldCity]
        var id: String { name }
    }

    static let groups: [Group] = [
        Group(name: "East Asia", cities: [
            WorldCity(name: "Beijing", region: "China", longitude: 116.41),
            WorldCity(name: "Shanghai", region: "China", longitude: 121.47),
            WorldCity(name: "Guangzhou", region: "China", longitude: 113.26),
            WorldCity(name: "Chengdu", region: "China", longitude: 104.07),
            WorldCity(name: "Ürümqi", region: "China", longitude: 87.62),
            WorldCity(name: "Hong Kong", region: "China", longitude: 114.17),
            WorldCity(name: "Taipei", region: "Taiwan", longitude: 121.56),
            WorldCity(name: "Tokyo", region: "Japan", longitude: 139.69),
            WorldCity(name: "Osaka", region: "Japan", longitude: 135.50),
            WorldCity(name: "Seoul", region: "South Korea", longitude: 126.98),
            WorldCity(name: "Ulaanbaatar", region: "Mongolia", longitude: 106.92),
        ]),
        Group(name: "Southeast & South Asia", cities: [
            WorldCity(name: "Singapore", region: "Singapore", longitude: 103.82),
            WorldCity(name: "Bangkok", region: "Thailand", longitude: 100.50),
            WorldCity(name: "Jakarta", region: "Indonesia", longitude: 106.85),
            WorldCity(name: "Kuala Lumpur", region: "Malaysia", longitude: 101.69),
            WorldCity(name: "Manila", region: "Philippines", longitude: 120.98),
            WorldCity(name: "Hanoi", region: "Vietnam", longitude: 105.83),
            WorldCity(name: "New Delhi", region: "India", longitude: 77.21),
            WorldCity(name: "Mumbai", region: "India", longitude: 72.88),
            WorldCity(name: "Bengaluru", region: "India", longitude: 77.59),
            WorldCity(name: "Dhaka", region: "Bangladesh", longitude: 90.41),
            WorldCity(name: "Karachi", region: "Pakistan", longitude: 67.01),
            WorldCity(name: "Kathmandu", region: "Nepal", longitude: 85.32),
        ]),
        Group(name: "Middle East & Central Asia", cities: [
            WorldCity(name: "Dubai", region: "UAE", longitude: 55.27),
            WorldCity(name: "Riyadh", region: "Saudi Arabia", longitude: 46.68),
            WorldCity(name: "Tehran", region: "Iran", longitude: 51.39),
            WorldCity(name: "Istanbul", region: "Türkiye", longitude: 28.98),
            WorldCity(name: "Tel Aviv", region: "Israel", longitude: 34.78),
            WorldCity(name: "Tashkent", region: "Uzbekistan", longitude: 69.24),
        ]),
        Group(name: "Europe", cities: [
            WorldCity(name: "London", region: "United Kingdom", longitude: -0.13),
            WorldCity(name: "Paris", region: "France", longitude: 2.35),
            WorldCity(name: "Berlin", region: "Germany", longitude: 13.40),
            WorldCity(name: "Madrid", region: "Spain", longitude: -3.70),
            WorldCity(name: "Rome", region: "Italy", longitude: 12.50),
            WorldCity(name: "Amsterdam", region: "Netherlands", longitude: 4.90),
            WorldCity(name: "Moscow", region: "Russia", longitude: 37.62),
            WorldCity(name: "Athens", region: "Greece", longitude: 23.73),
            WorldCity(name: "Stockholm", region: "Sweden", longitude: 18.07),
            WorldCity(name: "Zürich", region: "Switzerland", longitude: 8.54),
        ]),
        Group(name: "Africa", cities: [
            WorldCity(name: "Cairo", region: "Egypt", longitude: 31.24),
            WorldCity(name: "Lagos", region: "Nigeria", longitude: 3.38),
            WorldCity(name: "Nairobi", region: "Kenya", longitude: 36.82),
            WorldCity(name: "Johannesburg", region: "South Africa", longitude: 28.05),
            WorldCity(name: "Casablanca", region: "Morocco", longitude: -7.59),
            WorldCity(name: "Addis Ababa", region: "Ethiopia", longitude: 38.76),
        ]),
        Group(name: "North America", cities: [
            WorldCity(name: "New York", region: "USA", longitude: -74.01),
            WorldCity(name: "Los Angeles", region: "USA", longitude: -118.24),
            WorldCity(name: "Chicago", region: "USA", longitude: -87.63),
            WorldCity(name: "San Francisco", region: "USA", longitude: -122.42),
            WorldCity(name: "Toronto", region: "Canada", longitude: -79.38),
            WorldCity(name: "Vancouver", region: "Canada", longitude: -123.12),
            WorldCity(name: "Mexico City", region: "Mexico", longitude: -99.13),
        ]),
        Group(name: "South America", cities: [
            WorldCity(name: "São Paulo", region: "Brazil", longitude: -46.63),
            WorldCity(name: "Rio de Janeiro", region: "Brazil", longitude: -43.17),
            WorldCity(name: "Buenos Aires", region: "Argentina", longitude: -58.38),
            WorldCity(name: "Lima", region: "Peru", longitude: -77.04),
            WorldCity(name: "Bogotá", region: "Colombia", longitude: -74.07),
            WorldCity(name: "Santiago", region: "Chile", longitude: -70.65),
        ]),
        Group(name: "Oceania", cities: [
            WorldCity(name: "Sydney", region: "Australia", longitude: 151.21),
            WorldCity(name: "Melbourne", region: "Australia", longitude: 144.96),
            WorldCity(name: "Perth", region: "Australia", longitude: 115.86),
            WorldCity(name: "Auckland", region: "New Zealand", longitude: 174.76),
            WorldCity(name: "Honolulu", region: "USA", longitude: -157.86),
        ]),
    ]

    static let all: [WorldCity] = groups.flatMap(\.cities)

    static func search(_ query: String) -> [WorldCity] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return all }
        return all.filter {
            $0.name.lowercased().contains(q) || $0.region.lowercased().contains(q)
        }
    }
}
