import SwiftUI
import UIKit
import AVFoundation

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var appState: AppState
    @State private var showSettings = false
    @State private var showCleaner = false
    @StateObject private var patchStore = PatchProjectStore()
    @State private var patchOperationBusy = false
    @State private var patchMessage = "PRONTO — SELECIONE UM PATCH"
    @State private var selectedGame: GameMode = .normal
    // FF Normal states
    @State private var aimDragEnabled = false
    @State private var aimNeckEnabled = false
    @State private var hspeitoffEnabled = false
    @State private var hyperBalamagicaEnabled = false
    @State private var aimBodyPackageEnabled = false
    @State private var aimChestPackageEnabled = false
    @State private var magicEnabled = false
    // FF MAX states
    @State private var maxAimDragEnabled = false
    @State private var maxAimNeckEnabled = false
    @State private var maxHspeitoffEnabled = false
    @State private var maxHyperBalamagicaEnabled = false
    @State private var maxAimBodyPackageEnabled = false
    @State private var maxAimChestPackageEnabled = false
    @State private var maxMagicEnabled = false

    private enum GameMode: String, CaseIterable {
        case normal = "FF NORMAL"
        case max    = "FF MAX"
        var launchScheme: String { self == .normal ? "freefireth" : "freefiremax" }
        var patchPrefix: String { self == .normal ? "voidlabs" : "OGIOS" }
        var displayColor: Color { self == .normal ? AppTheme.accent : Color(hue: 0.55, saturation: 0.9, brightness: 0.95) }
    }

    var body: some View {
        ZStack {
            AnimatedHyperBackdrop()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    brandHeader
                    devicePanel
                    patchOptions
                    gameLaunchPanel
                    footerStatus
                    developerCredits
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showCleaner) {
            CleanerView()
        }
        .sheet(item: $patchStore.passwordRequest, onDismiss: patchStore.cancelUnlock) { _ in
            PatchUnlockPrompt(store: patchStore)
        }
        .onAppear { syncPatchStates() }
        .onChange(of: scenePhase) { phase in
            guard phase == .active, !patchOperationBusy else { return }
            syncPatchStates()
            patchMessage = "PRONTO — SELECIONE UM PATCH"
        }
    }

    private var brandHeader: some View {
        HStack(spacing: 14) {
            AppLogo(size: 64, cornerRadius: 16)

            VStack(alignment: .leading, spacing: 3) {
                Text("VOIDLABS")
                    .font(.system(size: 25, weight: .black, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(.white)
                Text("CENTRAL DE PATCHES")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.7)
                    .foregroundStyle(AppTheme.accent)
            }

            Spacer()

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 48, height: 48)
                    .background(Color.black.opacity(0.38), in: Circle())
                    .overlay(Circle().stroke(AppTheme.accent.opacity(0.42), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open settings")
        }
    }

    private var devicePanel: some View {
        VStack(spacing: 0) {
            panelTitle("STATUS DO DISPOSITIVO", icon: "shield.lefthalf.filled")
            statusRow(icon: "apple.logo", title: "iOS", value: AppInfo.osVersion, color: AppTheme.secondaryAccent)
            statusRow(icon: "iphone", title: "Dispositivo", value: AppInfo.displayMachineName, color: AppTheme.secondaryAccent)
            statusRow(icon: "checkmark.seal.fill", title: "Suporte", value: appState.isSupported ? "SUPORTADO" : "NÃO SUPORTADO", color: appState.isSupported ? .green : .red)
        }
        .padding(16)
        .background(Color.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(AppTheme.accent.opacity(0.38), lineWidth: 1))
    }

    private var patchOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                panelTitle("OPÇÕES DE PATCH", icon: "bolt.fill")
                Spacer()
                Text("SELECIONE PARA ATIVAR")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }

            // Game mode switcher
            HStack(spacing: 0) {
                ForEach(GameMode.allCases, id: \.rawValue) { mode in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                            selectedGame = mode
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: mode == .normal ? "gamecontroller.fill" : "bolt.shield.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text(mode.rawValue)
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .tracking(1)
                        }
                        .foregroundStyle(selectedGame == mode ? .white : .white.opacity(0.45))
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(
                            selectedGame == mode ? AppTheme.accent.opacity(0.28) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(selectedGame == mode ? AppTheme.accent.opacity(0.7) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(Color.black.opacity(0.38), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.accent.opacity(0.18), lineWidth: 1))

            if selectedGame == .normal {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    patchCard(name: "Hs Alto",     target: "FREE FIRE • NORMAL", package: "Cryptroic File (6).3105",  color: AppTheme.accent, state: $aimDragEnabled)
                    patchCard(name: "Hs pescoço",  target: "FREE FIRE • NORMAL", package: "Cryptroic File (7).3105",  color: AppTheme.accent, state: $aimNeckEnabled)
                    patchCard(name: "Holograma",   target: "FREE FIRE • NORMAL", package: "Cryptroic File (8).3105",  color: AppTheme.accent, state: $hspeitoffEnabled)
                    patchCard(name: "Magic",       target: "FREE FIRE • NORMAL", package: "Cryptroic File (10).3105", color: AppTheme.accent, state: $hyperBalamagicaEnabled)
                    patchCard(name: "Skin Mendela", target: "FREE FIRE • NORMAL", package: "Cryptroic File (12).3105", color: AppTheme.accent, state: $aimBodyPackageEnabled)
                    patchCard(name: "Skin V1",     target: "FREE FIRE • NORMAL", package: "Cryptroic File (14).3105", color: AppTheme.accent, state: $magicEnabled)
                }
                .transition(.opacity.combined(with: .move(edge: .leading)))
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    patchCard(name: "Hs Alto",     target: "FREE FIRE • MAX", package: "OGIOS File (6).3105",  color: AppTheme.accent, state: $maxAimDragEnabled)
                    patchCard(name: "Hs pescoço",  target: "FREE FIRE • MAX", package: "OGIOS File (7).3105",  color: AppTheme.accent, state: $maxAimNeckEnabled)
                    patchCard(name: "Holograma",   target: "FREE FIRE • MAX", package: "OGIOS File (8).3105",  color: AppTheme.accent, state: $maxHspeitoffEnabled)
                    patchCard(name: "Magic",       target: "FREE FIRE • MAX", package: "OGIOS File (10).3105", color: AppTheme.accent, state: $maxHyperBalamagicaEnabled)
                    patchCard(name: "Skin Mendela", target: "FREE FIRE • MAX", package: "OGIOS File (12).3105", color: AppTheme.accent, state: $maxAimBodyPackageEnabled)
                    patchCard(name: "Skin V1",     target: "FREE FIRE • MAX", package: "OGIOS File (14).3105", color: AppTheme.accent, state: $maxMagicEnabled)
                }
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }

            HStack(spacing: 8) {
                Circle().fill(patchMessage.localizedCaseInsensitiveContains("successful") ? .green : AppTheme.accent).frame(width: 7, height: 7)
                Text(patchOperationBusy ? "PROCESSANDO PATCH…" : patchMessage)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(2)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.34), in: Capsule())
        }
    }

    private func patchCard(name: String, target: String, package: String, color: Color, state: Binding<Bool>) -> some View {
        PatchOptionCard(name: name, target: target, color: color, isEnabled: state, isBusy: patchOperationBusy) {
            togglePatch(packageFilename: package, state: state, name: name)
        }
    }

    private var gameLaunchPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            panelTitle("INICIAR JOGO", icon: "arrow.up.forward.app.fill")
            HStack(spacing: 12) {
                if selectedGame == .normal {
                    launchButton(title: "FF NORMAL", subtitle: "Free Fire Normal", color: AppTheme.accent, scheme: "freefireth")
                } else {
                    launchButton(title: "FF MAX", subtitle: "Free Fire MAX", color: AppTheme.accent, scheme: "freefiremax")
                }
            }
            Button {
                showCleaner = true
            } label: {
                Label("Limpar Cache e Temp", systemImage: "trash.slash.fill")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Color.black.opacity(0.40), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.accent.opacity(0.52), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open cache and temporary files cleaner")
        }
    }

    private func launchButton(title: String, subtitle: String, color: Color, scheme: String) -> some View {
        Button { openGame(scheme: scheme) } label: {
            VStack(alignment: .leading, spacing: 7) {
                Image(systemName: "arrow.up.right.square.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
            .padding(.horizontal, 14)
            .background(Color.black.opacity(0.40), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(color.opacity(0.38), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func lockedLaunchButton(title: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: "lock.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(color.opacity(0.72))
            Text(title)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
            Text(subtitle)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(color.opacity(0.72))
        }
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
        .padding(.horizontal, 14)
        .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(color.opacity(0.24), lineWidth: 1))
        .opacity(0.72)
        .accessibilityLabel("FF MAX locked, coming soon")
    }

    private var footerStatus: some View {
        HStack(spacing: 10) {
            Circle().fill(.green).frame(width: 9, height: 9).shadow(color: .green, radius: 6)
            Text("SISTEMA PRONTO")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.72))
            Spacer()
            Text("VOIDLABS • PRONTO")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.accent.opacity(0.8))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(Color.black.opacity(0.45), in: Capsule())
        .overlay(Capsule().stroke(AppTheme.accent.opacity(0.2), lineWidth: 1))
    }

    private var developerCredits: some View {
        VStack(spacing: 10) {
            Text("Desenvolvido por VoidLabs")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
                .multilineTextAlignment(.center)

            Text("Entrar no Discord")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.secondaryAccent.opacity(0.85))

            HStack(spacing: 10) {
                channelButton(title: "VoidLabs Discord", url: "https://discord.gg/2dm2zJgkkq")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    private func channelButton(title: String, url: String) -> some View {
        Button {
            guard let destination = URL(string: url) else { return }
            UIApplication.shared.open(destination)
        } label: {
            Label(title, systemImage: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(AppTheme.accent.opacity(0.18), in: Capsule())
                .overlay(Capsule().stroke(AppTheme.accent.opacity(0.42), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func panelTitle(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 12, weight: .black, design: .rounded))
            .tracking(1.4)
            .foregroundStyle(AppTheme.accent)
    }

    private func statusRow(icon: String, title: String, value: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 17, weight: .bold)).foregroundStyle(color).frame(width: 24)
            Text(title).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.58))
            Spacer()
            Text(value).font(.system(size: 14, weight: .black, design: .rounded)).foregroundStyle(.white)
        }
        .padding(.top, 14)
    }

    private func syncPatchStates() {
        // FF Normal
        aimDragEnabled            = isPatchActive("Cryptroic File (6).3105")
        aimNeckEnabled            = isPatchActive("Cryptroic File (7).3105")
        hspeitoffEnabled          = isPatchActive("Cryptroic File (8).3105")
        hyperBalamagicaEnabled    = isPatchActive("Cryptroic File (10).3105")
        aimBodyPackageEnabled     = isPatchActive("Cryptroic File (12).3105")
        aimChestPackageEnabled    = isPatchActive("Cryptroic File (2).3105")
        magicEnabled              = isPatchActive("Cryptroic File (14).3105")
        // FF MAX
        maxAimDragEnabled         = isPatchActive("OGIOS File (6).3105")
        maxAimNeckEnabled         = isPatchActive("OGIOS File (7).3105")
        maxHspeitoffEnabled       = isPatchActive("OGIOS File (8).3105")
        maxHyperBalamagicaEnabled = isPatchActive("OGIOS File (10).3105")
        maxAimBodyPackageEnabled  = isPatchActive("OGIOS File (12).3105")
        maxAimChestPackageEnabled = isPatchActive("OGIOS File (2).3105")
        maxMagicEnabled           = isPatchActive("OGIOS File (14).3105")
    }

    private func isPatchActive(_ packageFilename: String) -> Bool {
        patchStore.items.first(where: { $0.packageURL.lastPathComponent.caseInsensitiveCompare(packageFilename) == .orderedSame })
            .flatMap { DevicePatchService.latestReceipt(projectID: $0.id) } != nil
    }

    private enum PatchActionResult {
        case applied
        case restored
        case unavailable(String)
    }

    private func setPatchState(for packageFilename: String, enabled: Bool) {
        switch packageFilename {
        // FF Normal
        case "Cryptroic File (6).3105":  aimDragEnabled = enabled
        case "Cryptroic File (7).3105":  aimNeckEnabled = enabled
        case "Cryptroic File (8).3105":  hspeitoffEnabled = enabled
        case "Cryptroic File (10).3105": hyperBalamagicaEnabled = enabled
        case "Cryptroic File (12).3105": aimBodyPackageEnabled = enabled
        case "Cryptroic File (2).3105":  aimChestPackageEnabled = enabled
        case "Cryptroic File (14).3105": magicEnabled = enabled
        // FF MAX
        case "OGIOS File (6).3105":  maxAimDragEnabled = enabled
        case "OGIOS File (7).3105":  maxAimNeckEnabled = enabled
        case "OGIOS File (8).3105":  maxHspeitoffEnabled = enabled
        case "OGIOS File (10).3105": maxHyperBalamagicaEnabled = enabled
        case "OGIOS File (12).3105": maxAimBodyPackageEnabled = enabled
        case "OGIOS File (2).3105":  maxAimChestPackageEnabled = enabled
        case "OGIOS File (14).3105": maxMagicEnabled = enabled
        default: break
        }
    }

    private func togglePatch(packageFilename: String, state: Binding<Bool>, name: String = "") {
        guard !patchOperationBusy else { return }
        guard let item = patchStore.items.first(where: { $0.packageURL.lastPathComponent.caseInsensitiveCompare(packageFilename) == .orderedSame }) else {
            patchMessage = "ERROR — PACKAGE NOT FOUND"
            log("patch: package not found: \(packageFilename)")
            return
        }

        let wasEnabled = state.wrappedValue
        patchOperationBusy = true
        patchMessage = "PROCESSANDO PATCH…"
        let project = item.project
        let projectID = item.id
        let patchDisplayName = name

        DispatchQueue.global(qos: .userInitiated).async {
            let result: PatchActionResult
            do {
                if wasEnabled {
                    if let receipt = DevicePatchService.latestReceipt(projectID: projectID) {
                        do {
                            try DevicePatchService.restore(receipt: receipt)
                            result = .restored
                        } catch {
                            // Nao trava em ON: abandona receipt e desliga
                            DevicePatchService.forceDeactivate(projectID: projectID)
                            result = .restored
                            log("patch: restore soft-fail, forced OFF: \(error.localizedDescription)")
                        }
                    } else {
                        result = .restored
                    }
                } else {
                    guard let project else {
                        result = .unavailable("PASSWORD REQUIRED — UNLOCK PACKAGE")
                        DispatchQueue.main.async {
                            self.patchStore.requestUnlock(for: item)
                            self.patchMessage = "PASSWORD REQUIRED — ENTER PACKAGE PASSWORD"
                            self.patchOperationBusy = false
                        }
                        return
                    }
                    let isMax = self.selectedGame == .max || packageFilename.hasPrefix("OGIOS")
                    let targetBundle = isMax ? "com.dts.freefiremax" : "com.dts.freefireth"
                    _ = try DevicePatchService.apply(project: project, targetBundleID: targetBundle)
                    result = .applied
                }
            } catch {
                let msg = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                result = .unavailable("FAILED — \(msg)")
            }

            DispatchQueue.main.async {
                switch result {
                case .applied:
                    self.setPatchState(for: packageFilename, enabled: true)
                    self.patchMessage = "Inject Successful — \(patchDisplayName)"
                    PatchAudioFeedback.bypassActivated()
                case .restored:
                    self.setPatchState(for: packageFilename, enabled: false)
                    self.patchMessage = "Restore Successful — \(patchDisplayName)"
                    PatchAudioFeedback.originalRestored()
                case .unavailable(let message):
                    // Ao falhar o apply, garante OFF; ao falhar restore ja forçamos restored acima
                    if !wasEnabled {
                        self.setPatchState(for: packageFilename, enabled: false)
                    }
                    self.patchMessage = message
                }
                self.syncPatchStates()
                self.patchOperationBusy = false
            }
        }
    }

    private func openGame(scheme: String) {
        guard let url = URL(string: "\(scheme)://") else { return }
        UIApplication.shared.open(url, options: [:]) { success in
            log("launch: \(scheme) success=\(success)")
        }
    }
}

private struct PatchOptionCard: View {
    let name: String
    let target: String
    let color: Color
    @Binding var isEnabled: Bool
    let isBusy: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    Image(systemName: "bolt.fill").font(.system(size: 16, weight: .black)).foregroundStyle(color)
                    Spacer()
                    Text(isEnabled ? "ON" : "OFF")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(isEnabled ? .green : .white.opacity(0.58))
                }
                Text(name)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                Text(target)
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(1.3)
                    .foregroundStyle(color)
                HStack(spacing: 7) {
                    Circle().fill(isEnabled ? Color.green : Color.white.opacity(0.25)).frame(width: 8, height: 8)
                    Text(isEnabled ? "PATCH ATIVO" : "ATIVAR PATCH")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 142, alignment: .leading)
            .padding(14)
            .background(Color.black.opacity(0.52), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(isEnabled ? color.opacity(0.85) : color.opacity(0.28), lineWidth: isEnabled ? 1.5 : 1))
            .shadow(color: isEnabled ? color.opacity(0.20) : .clear, radius: 12)
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .opacity(isBusy ? 0.55 : 1)
        .accessibilityLabel("\(name), \(target), \(isEnabled ? "On" : "Off")")
    }
}

private enum PatchAudioFeedback {
    private static let synthesizer = AVSpeechSynthesizer()
    static func bypassActivated() { speak("Bypass ativado") }
    static func originalRestored() { speak("Bypass desativado") }
    private static func speak(_ message: String) {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true, options: [])
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: message)
        let voices = AVSpeechSynthesisVoice.speechVoices()
        utterance.voice = voices.first(where: {
            ($0.language.hasPrefix("pt-BR") || $0.language.hasPrefix("pt-PT") || $0.language.hasPrefix("pt")) && $0.gender == .female && $0.quality == .enhanced
        }) ?? voices.first(where: {
            $0.language.hasPrefix("pt-BR") || $0.language.hasPrefix("pt-PT") || $0.language.hasPrefix("pt")
        }) ?? AVSpeechSynthesisVoice(language: "pt-BR")
        utterance.rate = 0.43
        utterance.pitchMultiplier = 1.10
        utterance.volume = 0.90
        synthesizer.speak(utterance)
    }
}

private struct PatchUnlockPrompt: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PatchProjectStore
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Package password", text: $password)
                        .textContentType(.password)
                        .submitLabel(.done)
                        .onSubmit(unlock)
                        .onChange(of: password) { _ in store.clearUnlockError() }
                    if let errorKey = store.unlockErrorKey {
                        Text(AppLanguage.english.text(errorKey))
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                } footer: {
                    Text("Digite a senha uma vez para desbloquear este pacote VoidLabs neste dispositivo.")
                }
            }
            .navigationTitle("Unlock package")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Unlock", action: unlock)
                        .disabled(password.isEmpty || store.isBusy)
                }
            }
        }
    }

    private func unlock() {
        guard !password.isEmpty else { return }
        store.unlock(password: password)
    }
}

struct AnimatedHyperBackdrop: View {
    @State private var animate = false
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AppTheme.pageBackground
                Circle()
                    .fill(AppTheme.accent.opacity(0.12))
                    .frame(width: 280, height: 280)
                    .blur(radius: 70)
                    .offset(x: animate ? 120 : -120, y: -proxy.size.height * 0.23)
                Circle()
                    .fill(AppTheme.secondaryAccent.opacity(0.08))
                    .frame(width: 260, height: 260)
                    .blur(radius: 80)
                    .offset(x: animate ? -100 : 100, y: proxy.size.height * 0.22)
                GridOverlay()
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) { animate = true }
            }
        }
    }
}

private struct GridOverlay: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            let spacing: CGFloat = 44
            stride(from: CGFloat(0), through: size.width, by: spacing).forEach { x in
                path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height))
            }
            stride(from: CGFloat(0), through: size.height, by: spacing).forEach { y in
                path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(AppTheme.accent.opacity(0.055)), lineWidth: 1)
        }
    }
}
