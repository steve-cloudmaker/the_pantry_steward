import Foundation

enum QuantityFormatter {
    static func format(quantity: Double, unit: String) -> String {
        let value: String
        if quantity.truncatingRemainder(dividingBy: 1) == 0 {
            value = String(Int(quantity))
        } else {
            value = String(format: "%.2f", quantity)
        }
        let trimmedUnit = unit.trimmingCharacters(in: .whitespaces)
        if trimmedUnit.isEmpty || trimmedUnit == "each" {
            return value
        }
        return "\(value) \(trimmedUnit)"
    }
}
