import SwiftUI

struct LicenseActivationView: View {
    @ObservedObject var manager: LicenseManager
    @State private var key = ""
    @FocusState private var keyFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedHyperBackdrop().ignoresSafeArea()
                Color.black.opacity(0.18).ignoresSafeArea()
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            Spacer(minLength: 42)
                            headerSection
                            cardSection
                                .id("activation-card")
                            Spacer(minLength: 42)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 28)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: keyFocused) { focused in
                        guard focused else { return }
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo("activation-card", anchor: .center)
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 10) {
            AppLogo(size: 168, cornerRadius: 36)
                .padding(.bottom, 4)
            Text("VOIDLABS")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(.white)
            Text("Version: 1.1.0")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
            Text("Package: VoidLabs")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.secondaryAccent.opacity(0.9))
                .padding(.top, 3)
        }
    }

    private var cardSection: some View {
        VStack(spacing: 16) {
            titleRow
            subtitleText
            keyInput
            rememberToggle
            verifyButton
            statusMessage
        }
        .padding(20)
        .background(.ultraThinMaterial.opacity(0.72), in: RoundedRectangle(cornerRadius: 25, style: .continuous))
        .background(Color.gray.opacity(0.18), in: RoundedRectangle(cornerRadius: 25, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 25, style: .continuous).stroke(Color.white.opacity(0.16), lineWidth: 1))
        .padding(.horizontal, 22)
        .padding(.top, 26)
    }

    private var titleRow: some View {
        HStack(spacing: 10) {
            Image(systemName: manager.isBusy ? "arrow.triangle.2.circlepath" : "key.fill")
                .foregroundStyle(AppTheme.secondaryAccent)
                .font(.system(size: 16, weight: .bold))
            Text(manager.isBusy ? "Connecting to KeyAuth..." : "KeyAuth License Required")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
        }
    }

    private var subtitleText: some View {
        Text("Enter your KeyAuth license key to activate VoidLabs")
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.68))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var keyInput: some View {
        TextField("License key", text: $key)
            .focused($keyFocused)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.done)
            .onSubmit { activate() }
            .font(.system(size: 16, weight: .medium, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(Color.gray.opacity(0.22), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(AppTheme.accent.opacity(0.48), lineWidth: 1))
    }

    private var rememberToggle: some View {
        Toggle("Remember key on this device", isOn: $manager.rememberKey)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.72))
            .tint(AppTheme.accent)
    }

    private var verifyButton: some View {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let disabled = trimmed.isEmpty || manager.isBusy
        return Button(action: activate) {
            HStack(spacing: 9) {
                Image(systemName: manager.isBusy ? "hourglass" : "checkmark.shield.fill")
                Text(manager.isBusy ? "VERIFYING WITH KEYAUTH..." : "VERIFY AND CONTINUE")
            }
            .font(.system(size: 14, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .shadow(color: AppTheme.accent.opacity(0.30), radius: 14, y: 7)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.48 : 1)
    }

    @ViewBuilder
    private var statusMessage: some View {
        if let msg = manager.message {
            let color: Color = manager.isActive ? Color.green : Color.red.opacity(0.95)
            Text(msg)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.gray.opacity(0.20), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    // MARK: - Helpers

    private func activate() {
        keyFocused = false
        manager.activate(key: key)
    }
}
