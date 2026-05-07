import SwiftUI

/// Lets a member submit a drink that isn't in the catalog. Mirrors
/// SubmitCigarView. Goes into `drinks_pending` for moderator review.
struct SubmitDrinkView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var category: String?
    @State private var subtype = ""
    @State private var isSubmitting = false
    @State private var didSubmit = false
    @State private var error: String?

    /// Categories that already exist in the catalog. We surface these as
    /// the picker options so submissions stay consistent.
    private let categories = [
        "whisky", "beer", "rum", "tequila", "mezcal", "cognac",
        "armagnac", "port", "sherry", "madeira", "amaro",
        "wine", "cocktail", "coffee", "tea", "non-alcoholic", "other",
    ]

    private let repo: DrinkRepository = LiveDrinkRepository()

    var body: some View {
        NavigationStack {
            ZStack {
                FTColor.background.ignoresSafeArea()
                if didSubmit { successView } else { formView }
            }
            .navigationTitle("Add a Drink")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                if !didSubmit {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Submit") {
                            Task { await submit() }
                        }
                        .disabled(isSubmitting || !canSubmit)
                        .tint(FTColor.gold)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var formView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FTSpace.lg) {
                Text("Tell us what we missed.")
                    .font(FTType.body(14))
                    .foregroundStyle(FTColor.inkMuted)

                FTField(title: "Name", text: $name, placeholder: "Lagavulin 16")

                VStack(alignment: .leading, spacing: FTSpace.xs) {
                    Text("CATEGORY")
                        .font(FTType.caption(11, weight: .semibold))
                        .foregroundStyle(FTColor.inkMuted).tracking(1)
                    Menu {
                        ForEach(categories, id: \.self) { c in
                            Button(c.capitalized) { category = c }
                        }
                    } label: {
                        HStack {
                            Text(category?.capitalized ?? "Choose")
                                .font(FTType.body(15))
                                .foregroundStyle(category == nil ? FTColor.inkMuted : FTColor.ink)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundStyle(FTColor.inkFaint)
                        }
                        .padding(FTSpace.md)
                        .background(FTColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: FTRadius.md))
                    }
                }

                FTField(title: "Subtype (optional)", text: $subtype,
                        placeholder: "Islay single malt, Belgian Quadrupel, Doppelbock…")

                if let error {
                    Text(error)
                        .font(FTType.caption(12))
                        .foregroundStyle(FTColor.danger)
                }

                Text("A moderator will review and add it to the catalog. You'll see it in Explore once approved.")
                    .font(FTType.caption(11))
                    .foregroundStyle(FTColor.inkFaint)
                    .padding(.top, FTSpace.sm)
            }
            .padding(FTSpace.xl)
        }
    }

    private var successView: some View {
        VStack(spacing: FTSpace.lg) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(FTColor.gold)
            Text("Submitted.")
                .font(FTType.display(28))
                .foregroundStyle(FTColor.ink)
            Text("Thanks for helping us grow the bar.")
                .font(FTType.body(14))
                .foregroundStyle(FTColor.inkMuted)
            FTButton(title: "Done", style: .gold) { dismiss() }
                .padding(.horizontal, FTSpace.xl)
                .padding(.top, FTSpace.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(FTSpace.xl)
    }

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func submit() async {
        isSubmitting = true; defer { isSubmitting = false }
        do {
            try await repo.submitPending(
                name: name.trimmingCharacters(in: .whitespaces),
                category: category,
                subtype: subtype.isEmpty ? nil : subtype
            )
            HapticsService.shared.success()
            didSubmit = true
        } catch {
            self.error = "Couldn't submit: \(error.localizedDescription)"
        }
    }
}

private struct FTField: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpace.xs) {
            Text(title.uppercased())
                .font(FTType.caption(11, weight: .semibold))
                .foregroundStyle(FTColor.inkMuted)
                .tracking(1)
            TextField("", text: $text,
                      prompt: Text(placeholder).foregroundColor(FTColor.inkFaint))
                .padding(FTSpace.md)
                .background(FTColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: FTRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: FTRadius.md)
                        .stroke(FTColor.divider, lineWidth: FTStroke.hairline)
                )
                .foregroundStyle(FTColor.ink)
        }
    }
}
