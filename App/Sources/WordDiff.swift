/// 2 つの英文を単語ごとに比べ、同じ・消えた・増えたに分ける（最長共通部分列）。
enum WordDiff {
    enum Kind: Equatable, Sendable {
        case same
        case removed
        case added
    }

    struct Part: Equatable, Sendable {
        var kind: Kind
        var text: String
    }

    static func words(_ text: String) -> [String] {
        text.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    static func compare(_ before: String, _ after: String) -> [Part] {
        let a = words(before)
        let b = words(after)
        let n = a.count
        let m = b.count
        // lcs[i][j] = a[i...] と b[j...] の共通部分列の長さ
        var lcs = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        if n > 0, m > 0 {
            for i in stride(from: n - 1, through: 0, by: -1) {
                for j in stride(from: m - 1, through: 0, by: -1) {
                    lcs[i][j] = a[i] == b[j] ? lcs[i + 1][j + 1] + 1 : max(lcs[i + 1][j], lcs[i][j + 1])
                }
            }
        }
        var parts: [Part] = []
        var i = 0
        var j = 0
        while i < n, j < m {
            if a[i] == b[j] {
                parts.append(Part(kind: .same, text: a[i]))
                i += 1
                j += 1
            } else if lcs[i + 1][j] >= lcs[i][j + 1] {
                parts.append(Part(kind: .removed, text: a[i]))
                i += 1
            } else {
                parts.append(Part(kind: .added, text: b[j]))
                j += 1
            }
        }
        while i < n {
            parts.append(Part(kind: .removed, text: a[i]))
            i += 1
        }
        while j < m {
            parts.append(Part(kind: .added, text: b[j]))
            j += 1
        }
        return parts
    }

    /// 変わった単語の数（消えた＋増えた）
    static func changeCount(_ parts: [Part]) -> Int {
        parts.filter { $0.kind != .same }.count
    }
}
