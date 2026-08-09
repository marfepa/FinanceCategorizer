import Foundation
import LocalAuthentication
import Observation

@MainActor
@Observable
final class AppLockViewModel {
    private(set) var isLocked = false
    private(set) var isAuthenticating = false
    private(set) var errorMessage: String?

    func configure(isEnabled: Bool, reason: String) async {
        guard isEnabled else {
            isLocked = false
            errorMessage = nil
            return
        }
        isLocked = true
        await authenticate(reason: reason)
    }

    func lockIfEnabled(_ isEnabled: Bool) {
        guard isEnabled else { return }
        isLocked = true
        errorMessage = nil
    }

    func authenticate(reason: String) async {
        guard isLocked, !isAuthenticating else { return }
        isAuthenticating = true
        errorMessage = nil
        defer { isAuthenticating = false }

        let context = LAContext()
        context.localizedCancelTitle = String(localized: "Cancel")
        var evaluationError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &evaluationError) else {
            errorMessage = evaluationError?.localizedDescription ?? String(localized: "Authentication is not available on this device.")
            return
        }

        do {
            if try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) {
                isLocked = false
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
