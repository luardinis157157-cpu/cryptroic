import Combine
import Foundation
import Security
import UIKit

// ══════════════════════════════════════════════
//  KeyAuth — Credenciais do seu painel
// ══════════════════════════════════════════════
private let kKeyAuthAppName  = "external ios"
private let kKeyAuthOwnerID  = "67aA3YHdzI"
private let kKeyAuthVersion  = "1.0"
private let kKeyAuthAPI      = "https://keyauth.win/api/1.3/"

@MainActor
final class LicenseManager: ObservableObject {

    @Published private(set) var isActive     = false
    @Published private(set) var isBusy       = false
    @Published private(set) var message: String?
    @Published private(set) var expiresAt: String?
    @Published private(set) var daysRemaining: Int?
    @Published var rememberKey = true

    private let service     = "com.tefvx.external-ios.activation"
    private let keyAccount  = "license-key"

    /// SessionID retornado pelo init do KeyAuth
    private var sessionID: String?

    init() {
        if let saved = storedKey(), !saved.isEmpty {
            Task { await verifyOnline(key: saved, silent: true) }
        }
    }

    var hasRememberedKey: Bool {
        if let k = storedKey(), !k.isEmpty { return true }
        return false
    }

    func beginLaunchSession() {
        guard let saved = storedKey(), !saved.isEmpty else {
            isActive = false; return
        }
        Task { await verifyOnline(key: saved, silent: true) }
    }

    func activate(key: String, isAutoLogin: Bool = false) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task { await verifyOnline(key: trimmed, silent: false) }
    }

    func rememberedKey() -> String? { storedKey() }

    func refresh() {
        guard let saved = storedKey(), !saved.isEmpty else { return }
        Task { await verifyOnline(key: saved, silent: false) }
    }

    func deactivate() {
        deleteKey()
        isActive      = false
        message       = nil
        expiresAt     = nil
        daysRemaining = nil
        sessionID     = nil
    }

    // MARK: - KeyAuth Init

    /// Inicializa a sessão com o servidor do KeyAuth
    private func initSession() async -> Bool {
        var components = URLComponents(string: kKeyAuthAPI)!
        components.queryItems = [
            URLQueryItem(name: "type",    value: "init"),
            URLQueryItem(name: "name",    value: kKeyAuthAppName),
            URLQueryItem(name: "ownerid", value: kKeyAuthOwnerID),
            URLQueryItem(name: "ver",     value: kKeyAuthVersion),
        ]

        guard let url = components.url else { return false }

        do {
            var req = URLRequest(url: url, timeoutInterval: 15)
            req.httpMethod = "GET"
            let (data, _) = try await URLSession.shared.data(for: req)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            let success = json?["success"] as? Bool ?? false
            if success {
                sessionID = json?["sessionid"] as? String
                return true
            } else {
                let msg = json?["message"] as? String ?? "Erro ao inicializar"
                message = msg
                return false
            }
        } catch {
            return false
        }
    }

    // MARK: - KeyAuth License Check

    private func verifyOnline(key: String, silent: Bool) async {
        if !silent { isBusy = true }

        // Passo 1: Inicializa sessão no KeyAuth
        let initialized = await initSession()
        guard initialized, let sid = sessionID else {
            if !silent { message = "Sem conexão — tente novamente" }
            if !silent { isBusy = false }
            return
        }

        // Passo 2: Valida a key
        let hwid = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"

        var components = URLComponents(string: kKeyAuthAPI)!
        components.queryItems = [
            URLQueryItem(name: "type",      value: "license"),
            URLQueryItem(name: "key",       value: key),
            URLQueryItem(name: "sessionid", value: sid),
            URLQueryItem(name: "name",      value: kKeyAuthAppName),
            URLQueryItem(name: "ownerid",   value: kKeyAuthOwnerID),
            URLQueryItem(name: "hwid",      value: hwid),
        ]

        guard let url = components.url else {
            if !silent { message = "Erro ao conectar" }
            if !silent { isBusy = false }
            return
        }

        do {
            var req = URLRequest(url: url, timeoutInterval: 15)
            req.httpMethod = "GET"
            let (data, _) = try await URLSession.shared.data(for: req)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            let success = json?["success"] as? Bool ?? false
            let msg     = json?["message"] as? String ?? ""

            // Tenta pegar info de subscription/expiry
            let info = json?["info"] as? [String: Any]
            let subscriptions = info?["subscriptions"] as? [[String: Any]]
            var expiry: String? = nil
            var days: Int? = nil

            if let subs = subscriptions, let first = subs.first {
                if let exp = first["expiry"] as? String {
                    // KeyAuth retorna timestamp Unix como string
                    if let ts = Double(exp) {
                        let expiryDate = Date(timeIntervalSince1970: ts)
                        let formatter = DateFormatter()
                        formatter.dateFormat = "dd/MM/yyyy HH:mm"
                        formatter.timeZone = TimeZone(identifier: "America/Sao_Paulo")
                        expiry = formatter.string(from: expiryDate)

                        let remaining = Calendar.current.dateComponents([.day], from: Date(), to: expiryDate)
                        days = remaining.day
                    }
                }
            }

            isActive      = success
            expiresAt     = expiry
            daysRemaining = days

            if success {
                if rememberKey { saveKey(key) }
                if let d = days {
                    message = "Key válida — \(d) dia(s) restante(s)"
                } else {
                    message = "Key válida ✅"
                }
            } else {
                if !silent { message = msg.isEmpty ? "Key inválida" : msg }
                deleteKey()
            }
        } catch {
            if !silent { message = "Sem conexão — tente novamente" }
        }

        if !silent { isBusy = false }
    }

    // MARK: - Keychain

    private func storedKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: keyAccount,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func saveKey(_ value: String) {
        let base: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: keyAccount
        ]
        SecItemDelete(base as CFDictionary)
        var item = base
        item[kSecValueData as String]      = Data(value.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    private func deleteKey() {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: keyAccount
        ]
        SecItemDelete(query as CFDictionary)
    }
}
