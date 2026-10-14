import Foundation

/// Inline calculator: + - * / % ^, parentheses, unary minus; "x", "×" and "÷" accepted; "," is a decimal point.
public enum Calculator {
    public static func evaluate(_ input: String) -> Double? {
        let s = input.replacingOccurrences(of: " ", with: "")
        guard s.count >= 3,
              s.contains(where: \.isNumber),
              s.contains(where: { "+-*/^%x×÷".contains($0) }),
              s.allSatisfy({ "0123456789.,+-*/^%()x×÷".contains($0) })
        else { return nil }
        var parser = Parser(chars: Array(s))
        guard let value = parser.expression(), parser.atEnd, value.isFinite else { return nil }
        return value
    }

    public static func format(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 10
        f.usesGroupingSeparator = abs(value) >= 10_000
        return f.string(from: NSNumber(value: value)) ?? String(value)
    }

    private struct Parser {
        let chars: [Character]
        var i = 0

        var atEnd: Bool { i == chars.count }
        var peek: Character? { i < chars.count ? chars[i] : nil }

        mutating func expression() -> Double? {
            guard var value = term() else { return nil }
            while let op = peek, op == "+" || op == "-" {
                i += 1
                guard let rhs = term() else { return nil }
                value = op == "+" ? value + rhs : value - rhs
            }
            return value
        }

        mutating func term() -> Double? {
            guard var value = power() else { return nil }
            while let op = peek, "*x×/÷%".contains(op) {
                i += 1
                guard let rhs = power() else { return nil }
                switch op {
                case "/", "÷": value /= rhs
                case "%": value = value.truncatingRemainder(dividingBy: rhs)
                default: value *= rhs
                }
            }
            return value
        }

        mutating func power() -> Double? {
            guard let base = unary() else { return nil }
            if peek == "^" {
                i += 1
                guard let exponent = power() else { return nil }
                return pow(base, exponent)
            }
            return base
        }

        mutating func unary() -> Double? {
            if peek == "-" { i += 1; return unary().map { -$0 } }
            if peek == "+" { i += 1; return unary() }
            return primary()
        }

        mutating func primary() -> Double? {
            if peek == "(" {
                i += 1
                guard let value = expression(), peek == ")" else { return nil }
                i += 1
                return value
            }
            let start = i
            while let c = peek, c.isNumber || c == "." || c == "," { i += 1 }
            guard i > start else { return nil }
            return Double(String(chars[start..<i]).replacingOccurrences(of: ",", with: "."))
        }
    }
}
