import Foundation
import CryptoKit
import LocalAuthentication

enum AppLockService {
    static func hashPIN(_ pin: String) -> String {
        let digest = SHA256.hash(data: Data(pin.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func verify(pin: String, against pinHash: String) -> Bool {
        hashPIN(pin) == pinHash
    }

    static func canEvaluateBiometrics() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    static func authenticateWithBiometrics(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "取消"

        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
        } catch {
            return false
        }
    }
}
