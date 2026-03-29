import SwiftUI

struct SessionDetailView: View {
    @Environment(AppState.self) private var appState

    let session: ClaudeSession
    let service: ClaudeService

    init(session: ClaudeSession) {
        self.session = session
        self.service = session.resolveService()
    }

    var body: some View {
        ClaudeChatView(service: service)
            .task {
                service.appState = appState
                if service.messages.isEmpty, let sessionID = service.session.sessionID {
                    service.resumeSession(sessionID)
                }
            }
            .onAppear {
                session.hasNotification = false
            }
    }
}
