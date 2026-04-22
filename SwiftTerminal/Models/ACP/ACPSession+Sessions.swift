import Foundation

extension ACPSession {
    func newSession() {
        sessionTitle = nil
        isConnecting = true
        Task {
            await terminateAndRelaunch()
        }
    }
}
