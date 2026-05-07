import SwiftUI

/// Builds a smart, context-aware greeting line for the Home tab.
/// Returns a two-part `(prefix, suffix)` so the user's first name can be
/// rendered between them in a different color (white ink) while the
/// rest stays in muted gold — single-line attributed text via Text +.
///
/// Variations rotate based on:
///   - time of day (morning / afternoon / evening / late night)
///   - streak count (mild flex at 7+, 30+, 100+)
///   - whether they have an active "Usual" set (returning vs new)
///   - day of week (Sunday and Friday get a softer line)
struct GreetingCopy: Sendable {
    let prefix: String
    let suffix: String

    /// Picks a line based on the user's state.
    static func make(streak: Int, hasUsual: Bool, now: Date = .now) -> GreetingCopy {
        let hour = Calendar.current.component(.hour, from: now)
        let weekday = Calendar.current.component(.weekday, from: now) // 1 = Sunday

        // Streak milestones win — they're a flex worth saying.
        if streak >= 100 {
            return .init(prefix: "A hundred nights deep, ", suffix: ".")
        }
        if streak >= 30 {
            return .init(prefix: "Thirty nights running, ", suffix: ".")
        }
        if streak >= 14 {
            return .init(prefix: "Two weeks of nights, ", suffix: ".")
        }
        if streak >= 7 {
            return .init(prefix: "Seven and counting, ", suffix: ".")
        }
        if streak >= 3 {
            return .init(prefix: "Three nights running, ", suffix: ".")
        }

        // Late night gets its own atmosphere.
        if hour < 6 {
            return .init(prefix: "The fire's still going, ", suffix: ".")
        }

        // Morning — softer, no hurry.
        if hour < 12 {
            return .init(prefix: "Take it slow, ", suffix: ".")
        }

        // Afternoon — gentle.
        if hour < 17 {
            let day = weekday
            if day == 1 { // Sunday
                return .init(prefix: "An easy Sunday, ", suffix: ".")
            }
            return .init(prefix: "Pull up your chair, ", suffix: ".")
        }

        // Evening — primary copy.
        // Friday gets a slight wink.
        if weekday == 6 {
            return .init(prefix: "Friday's earned it, ", suffix: ". Your chair is ready.")
        }
        if hasUsual {
            return .init(prefix: "Welcome back, ", suffix: ". Your chair is ready.")
        }
        return .init(prefix: "Welcome, ", suffix: ". Your chair is ready.")
    }
}

/// Renders the greeting line with the user's first name highlighted in
/// ink white between the gold prefix and suffix. Falls back to a single
/// gold sentence when there's no name to highlight.
struct GreetingLine: View {
    let copy: GreetingCopy
    let firstName: String?

    var body: some View {
        if let firstName, !firstName.isEmpty {
            (Text(copy.prefix).foregroundStyle(FTColor.gold)
             + Text(firstName).foregroundStyle(FTColor.ink)
             + Text(copy.suffix).foregroundStyle(FTColor.gold))
                .font(FTType.display(28))
                .lineSpacing(2)
                .multilineTextAlignment(.leading)
        } else {
            // No name yet — pre-onboarding edge case.
            Text(copy.prefix.replacingOccurrences(of: ", ", with: "")
                 + copy.suffix)
                .font(FTType.display(28))
                .foregroundStyle(FTColor.gold)
        }
    }
}
