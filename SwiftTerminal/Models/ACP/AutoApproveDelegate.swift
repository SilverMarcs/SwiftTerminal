import Foundation
import ACP
import ACPModel

final class AutoApproveDelegate: ClientDelegate, @unchecked Sendable {

    func handlePermissionRequest(request: RequestPermissionRequest) async throws -> RequestPermissionResponse {
        let options = request.options
        if let allow = options.first(where: { $0.kind == "allow" }) ?? options.first {
            return RequestPermissionResponse(outcome: PermissionOutcome(optionId: allow.optionId))
        }
        return RequestPermissionResponse(outcome: PermissionOutcome(cancelled: true))
    }

    func handleFileReadRequest(_ path: String, sessionId: String, line: Int?, limit: Int?) async throws -> ReadTextFileResponse {
        throw ACPDelegateError.notSupported
    }

    func handleFileWriteRequest(_ path: String, content: String, sessionId: String) async throws -> WriteTextFileResponse {
        throw ACPDelegateError.notSupported
    }

    func handleTerminalCreate(command: String, sessionId: String, args: [String]?, cwd: String?, env: [EnvVariable]?, outputByteLimit: Int?) async throws -> CreateTerminalResponse {
        throw ACPDelegateError.notSupported
    }

    func handleTerminalOutput(terminalId: TerminalId, sessionId: String) async throws -> TerminalOutputResponse {
        throw ACPDelegateError.notSupported
    }

    func handleTerminalWaitForExit(terminalId: TerminalId, sessionId: String) async throws -> WaitForExitResponse {
        throw ACPDelegateError.notSupported
    }

    func handleTerminalKill(terminalId: TerminalId, sessionId: String) async throws -> KillTerminalResponse {
        throw ACPDelegateError.notSupported
    }

    func handleTerminalRelease(terminalId: TerminalId, sessionId: String) async throws -> ReleaseTerminalResponse {
        throw ACPDelegateError.notSupported
    }
}

private enum ACPDelegateError: Error {
    case notSupported
}
