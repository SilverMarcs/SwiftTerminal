import SwiftUI

struct SessionDetailView: View {
    let service: ClaudeService
    
    init(session: ClaudeSession) {
        self.service = session.resolveService()
    }

    var body: some View {
        ClaudeChatView(service: service)
            .task {
                if service.messages.isEmpty, let sessionID = service.session.sessionID {
                    service.resumeSession(sessionID)
                }
            }
    }
}
