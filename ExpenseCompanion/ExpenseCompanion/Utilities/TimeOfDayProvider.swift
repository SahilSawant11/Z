//
//  TimeOfDayProvider.swift
//  ExpenseCompanion
//
//  Drives the shifting pastel gradient background based on time of day.
//  Refreshes every 5 minutes, which is frequent enough to feel "alive"
//  without wasting battery on a per-second timer.
//

import SwiftUI
import Combine

enum DayPhase {
    case morning   // 5am–12pm
    case afternoon // 12pm–5pm
    case evening   // 5pm–9pm
    case night     // 9pm–5am

    static func current(for date: Date = .now) -> DayPhase {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<21: return .evening
        default: return .night
        }
    }

    /// Light-mode gradient colors for this phase.
    var lightColors: [Color] {
        switch self {
        case .morning:
            return [Color(hex: "FFE8D6"), Color(hex: "FFF3C4"), Color(hex: "FFD6E8")]
        case .afternoon:
            return [Color(hex: "D6E4FF"), Color(hex: "E0D6FF"), Color(hex: "C7EAFF")]
        case .evening:
            return [Color(hex: "6C5CE7").opacity(0.6), Color(hex: "FD79A8").opacity(0.5), Color(hex: "A29BFE").opacity(0.5)]
        case .night:
            return [Color(hex: "1B1B3A"), Color(hex: "2D1B4E"), Color(hex: "0F1035")]
        }
    }

    /// Dark-mode gradient — deep, desaturated tones so glass cards still pop.
    var darkColors: [Color] {
        [Color(hex: "0B0B1E"), Color(hex: "1A1230"), Color(hex: "13182B")]
    }
}

@MainActor
final class TimeOfDayProvider: ObservableObject {
    @Published private(set) var phase: DayPhase = .current()

    private var timer: AnyCancellable?

    init() {
        timer = Timer.publish(every: 300, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                self?.phase = .current(for: date)
            }
    }
}

extension Color {
    /// Convenience hex initializer for design-token colors defined above.
    init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        let r = Double((rgb & 0xFF0000) >> 16) / 255
        let g = Double((rgb & 0x00FF00) >> 8) / 255
        let b = Double(rgb & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
