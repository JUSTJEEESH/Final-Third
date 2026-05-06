import SwiftUI

struct AuthView: View {
    @Environment(AppContainer.self) private var container
    @State private var vm: AuthViewModel?

    var body: some View {
        ZStack {
            FTColor.background.ignoresSafeArea()
            content
        }
        .onAppear {
            if vm == nil { vm = AuthViewModel(auth: container.auth) }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let vm {
            switch vm.step {
            case .landing:       LandingView(vm: vm)
            case .email:         EmailView(vm: vm)
            case .profileSetup:  ProfileSetupView(vm: vm)
            }
        }
    }
}

private struct LandingView: View {
    @Bindable var vm: AuthViewModel

    var body: some View {
        VStack(spacing: FTSpace.xl) {
            Spacer()
            VStack(spacing: FTSpace.sm) {
                Text("The Final Third")
                    .font(FTType.display(40))
                    .foregroundStyle(FTColor.gold)
                Text("Pour a drink. Light a cigar. We've saved your chair.")
                    .font(FTType.body(15))
                    .foregroundStyle(FTColor.inkMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, FTSpace.xl)
            }
            Spacer()
            VStack(spacing: FTSpace.md) {
                FTButton(title: "Sign in with Apple", style: .gold, icon: "applelogo",
                         isLoading: vm.isWorking) {
                    Task { await vm.signInWithApple() }
                }
                FTButton(title: "Continue with email", style: .ghost) {
                    vm.step = .email
                }
                if let error = vm.error {
                    Text(error)
                        .font(FTType.caption(12))
                        .foregroundStyle(FTColor.danger)
                }
            }
            .padding(.horizontal, FTSpace.xl)
            Spacer().frame(height: FTSpace.xl)
        }
    }
}

private struct EmailView: View {
    @Bindable var vm: AuthViewModel
    @State private var isSignUp = false

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpace.lg) {
            Text(isSignUp ? "Create an account" : "Welcome back")
                .font(FTType.display(28))
                .foregroundStyle(FTColor.gold)

            VStack(spacing: FTSpace.md) {
                FTField(title: "Email", text: $vm.email, keyboard: .emailAddress)
                FTField(title: "Password", text: $vm.password, secure: true)
            }

            FTButton(title: isSignUp ? "Create account" : "Sign in",
                     style: .gold, isLoading: vm.isWorking) {
                Task { isSignUp ? await vm.signUpWithEmail() : await vm.signInWithEmail() }
            }

            Button(isSignUp ? "Have an account? Sign in" : "New here? Create an account") {
                isSignUp.toggle()
            }
            .font(FTType.caption(13))
            .foregroundStyle(FTColor.inkMuted)
            .frame(maxWidth: .infinity, alignment: .center)

            if let error = vm.error {
                Text(error).font(FTType.caption(12)).foregroundStyle(FTColor.danger)
            }

            Spacer()
        }
        .padding(.horizontal, FTSpace.xl)
        .padding(.top, FTSpace.xxxl)
    }
}

private struct ProfileSetupView: View {
    @Bindable var vm: AuthViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FTSpace.lg) {
                Text("Tell us a little about yourself.")
                    .font(FTType.display(26)).foregroundStyle(FTColor.gold)

                FTField(title: "Name or handle", text: $vm.displayName)
                FTField(title: "@handle (optional)", text: $vm.handle)
                FTField(title: "City (optional)", text: $vm.city)

                Toggle(isOn: $vm.isHondurasLocal) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Honduras local").font(FTType.body(15, weight: .medium))
                        Text("We'll surface nearby events and locals.")
                            .font(FTType.caption(12)).foregroundStyle(FTColor.inkMuted)
                    }
                }
                .tint(FTColor.gold)

                FTButton(title: "Take my chair", style: .gold, isLoading: vm.isWorking) {
                    Task { await vm.saveProfile() }
                }

                if let error = vm.error {
                    Text(error).font(FTType.caption(12)).foregroundStyle(FTColor.danger)
                }
            }
            .padding(FTSpace.xl)
        }
    }
}

private struct FTField: View {
    let title: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var secure: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpace.xs) {
            Text(title).font(FTType.caption(11, weight: .semibold))
                .foregroundStyle(FTColor.inkMuted)
                .textCase(.uppercase)
            Group {
                if secure {
                    SecureField("", text: $text)
                } else {
                    TextField("", text: $text)
                        .keyboardType(keyboard)
                        .textInputAutocapitalization(keyboard == .emailAddress ? .never : .sentences)
                        .autocorrectionDisabled(keyboard == .emailAddress)
                }
            }
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
