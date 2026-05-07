import SwiftUI

/// Lets a member submit a cigar that isn't in the catalog. Goes into
/// `cigars_pending` for moderator review (the LiveCigarRepository.submitPending
/// path was already in place; this is the UI for it).
struct SubmitCigarView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var brand = ""
    @State private var line = ""
    @State private var vitola = ""
    @State private var country: String?
    @State private var isSubmitting = false
    @State private var didSubmit = false
    @State private var error: String?

    private let countries = [
        "Cuba", "Nicaragua", "Honduras", "Dominican Republic",
        "Mexico", "Brazil", "Ecuador", "USA", "Other",
    ]

    private let repo: CigarRepository = LiveCigarRepository()

    var body: some View {
        NavigationStack {
            ZStack {
                FTColor.background.ignoresSafeArea()
                if didSubmit { successView } else { formView }
            }
            .navigationTitle("Add a Cigar")
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

                FTField(title: "Brand", text: $brand, placeholder: "Padrón")
                FTField(title: "Line", text: $line, placeholder: "1964 Anniversary")
                FTField(title: "Vitola (optional)", text: $vitola, placeholder: "Diplomático")

                VStack(alignment: .leading, spacing: FTSpace.xs) {
                    Text("COUNTRY")
                        .font(FTType.caption(11, weight: .semibold))
                        .foregroundStyle(FTColor.inkMuted).tracking(1)
                    Menu {
                        ForEach(countries, id: \.self) { c in
                            Button(c) { country = c }
                        }
                    } label: {
                        HStack {
                            Text(country ?? "Choose")
                                .font(FTType.body(15))
                                .foregroundStyle(country == nil ? FTColor.inkMuted : FTColor.ink)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundStyle(FTColor.inkFaint)
                        }
                        .padding(FTSpace.md)
                        .background(FTColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: FTRadius.md))
                    }
                }

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
            Text("Thanks for helping us grow the library.")
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
        !brand.trimmingCharacters(in: .whitespaces).isEmpty
            && !line.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func submit() async {
        isSubmitting = true; defer { isSubmitting = false }
        do {
            try await repo.submitPending(
                brand: brand.trimmingCharacters(in: .whitespaces),
                line: line.trimmingCharacters(in: .whitespaces),
                vitola: vitola.isEmpty ? nil : vitola,
                country: country
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
