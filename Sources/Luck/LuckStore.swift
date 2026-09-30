import Foundation
import Observation
import SwiftUI

enum LuckCard: Int, CaseIterable, Codable {
    case angel, star, moon, eye, blackSun

    var numeral: String { ["I", "II", "III", "IV", "V"][rawValue] }

    var name: String {
        switch self {
        case .angel: localized("ANGEL")
        case .star: localized("STAR")
        case .moon: localized("MOON")
        case .eye: localized("EYE")
        case .blackSun: localized("BLACK SUN")
        }
    }

    var status: String {
        switch self {
        case .angel: localized("You're very lucky today")
        case .star: localized("You're lucky today")
        case .moon: localized("Just an ordinary day")
        case .eye: localized("Be careful today")
        case .blackSun: localized("You're unlucky today")
        }
    }

    var message: String {
        switch self {
        case .angel: localized("Your wings will carry you. Take the big step today.")
        case .star: localized("Your path is bright. A little courage is enough.")
        case .moon: localized("You hold the balance. No big win, no big loss.")
        case .eye: localized("Don't rush; think every step through twice.")
        case .blackSun: localized("Don't take risks. A new card awaits you tomorrow.")
        }
    }

    var color: Color {
        Color(hex: [0xf3d98a, 0xe9c27a, 0xd6dde8, 0xe59a5e, 0xd77a92][rawValue])
    }

    /// "Melek · I": the name in sentence case, lowercased with the UI language's rules (YILDIZ → Yıldız).
    var shortTitle: String {
        let locale = AppLanguage.current.locale
        return name.prefix(1) + name.dropFirst().lowercased(with: locale) + " · " + numeral
    }
}

/// One card per calendar day; drawing again the same day shows the same card, and it resets at midnight.
@MainActor @Observable
final class LuckStore {
    private struct Draw: Codable {
        var day: String
        var card: LuckCard
    }

    private static let key = "luck"
    @ObservationIgnored private let defaults: UserDefaults
    private var draw: Draw?
    /// The current day, updated by the system's day-change notification (also sent after waking from sleep),
    /// so a panel left open over midnight goes back to "draw your card".
    private var today = LuckStore.day(.now)

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        draw = defaults.data(forKey: Self.key).flatMap { try? JSONDecoder().decode(Draw.self, from: $0) }
        NotificationCenter.default.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.today = Self.day(.now) }
        }
    }

    /// The card drawn on `date`, or today if no date is given.
    func card(on date: Date? = nil) -> LuckCard? {
        guard let draw, draw.day == date.map(Self.day) ?? today else { return nil }
        return draw.card
    }

    /// Today's card, drawing a random one first if needed. `isNew` is true when it was just drawn.
    func drawToday(on date: Date = .now) -> (card: LuckCard, isNew: Bool) {
        if let card = card(on: date) { return (card, false) }
        let new = Draw(day: Self.day(date), card: LuckCard.allCases.randomElement()!)
        today = new.day
        draw = new
        defaults.set(try? JSONEncoder().encode(new), forKey: Self.key)
        return (new.card, true)
    }

    nonisolated static func day(_ date: Date) -> String {
        date.formatted(.verbatim(
            "\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits)",
            timeZone: .current, calendar: Calendar(identifier: .gregorian)
        ))
    }
}
