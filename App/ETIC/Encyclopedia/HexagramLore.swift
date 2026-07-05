import Foundation

/// 卦象百科条目：一卦的经文（卦辞 / 彖辞 / 六爻辞）。
///
/// 数据为公有领域《周易》经文，随包内置（`Encyclopedia/Data/zhouyi.json`），完全离线。
/// 与引擎盘面无耦合，仅供浏览查阅。
struct HexagramLore: Decodable, Identifiable, Hashable {
    let name: String            // 引擎卦名，如「乾为天」
    let short: String           // 通行短卦名，如「乾」
    let judgment: String        // 卦辞
    let lines: [String: String] // 爻辞，键为「1」…「6」（初→上）
    let tuan: String?           // 彖辞（可空）

    /// 周易通行卦序（1-64），由加载时注入，不参与 JSON 解码。
    var index: Int = 0

    enum CodingKeys: String, CodingKey {
        case name, short, judgment, lines, tuan
    }

    var id: String { name }

    /// 六爻辞，按初→上排序。
    var orderedLines: [(position: Int, text: String)] {
        (1...6).compactMap { pos in
            guard let text = lines[String(pos)] else { return nil }
            return (pos, text)
        }
    }
}

/// 内置周易经文的加载器（一次性解码并缓存）。
enum EncyclopediaStore {
    /// 全部 64 卦，按内置顺序（周易通行卦序）。
    static let all: [HexagramLore] = load()

    private static func load() -> [HexagramLore] {
        guard let url = Bundle.main.url(forResource: "zhouyi", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let items = try? JSONDecoder().decode([HexagramLore].self, from: data) else {
            return []
        }
        return items.enumerated().map { i, item in
            var copy = item
            copy.index = i + 1
            return copy
        }
    }

    /// 按卦名 / 短名 / 卦辞关键字过滤。
    static func search(_ query: String) -> [HexagramLore] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return all }
        return all.filter {
            $0.name.contains(q) || $0.short.contains(q) || $0.judgment.contains(q)
        }
    }

    /// 根据卦序获取通俗解读，支持 i18n。未录入的卦返回 nil。
    static func explanation(for index: Int) -> String? {
        let key = "hexagram.explanation.\(index)"
        let text = LocalizationStore.string(key)
        return text == key ? nil : text
    }
}
