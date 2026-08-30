//
//  CurrencyFormatter.swift
//  ExpenseCompanion
//

import Foundation

enum CurrencyFormatter {
    /// Formats an amount using the given ISO currency code (e.g. "INR", "USD", "EUR").
    /// Falls back to a plain 2-decimal string if formatting fails for any reason.
    static func format(_ amount: Double, currencyCode: String = "INR") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = amount.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2
        return formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
    }

    static func symbol(for currencyCode: String) -> String {
        switch currencyCode {
        case "INR": return "₹"
        case "USD": return "$"
        case "EUR": return "€"
        default: return Locale.current.localizedCurrencySymbol(forCurrencyCode: currencyCode) ?? currencyCode
        }
    }
}

private extension Locale {
    func localizedCurrencySymbol(forCurrencyCode code: String) -> String? {
        NSLocale(localeIdentifier: identifier).displayName(forKey: .currencySymbol, value: code)
    }
}
