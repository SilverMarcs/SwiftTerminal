import Foundation

@Observable
final class CommandRunner {

    struct RunState {
        let process: Process
        let pipe: Pipe
        var output: String = ""
        var exitCode: Int32?

        var isRunning: Bool { process.isRunning }
    }

    private(set) var states: [CommandEntry: RunState] = [:]

    subscript(_ entry: CommandEntry) -> RunState? {
        states[entry]
    }

    func isRunning(_ entry: CommandEntry) -> Bool {
        states[entry]?.isRunning == true
    }

    func run(_ entry: CommandEntry, in directory: URL) {
        stop(entry)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", entry.command]
        process.currentDirectoryURL = directory

        var env = ProcessInfo.processInfo.environment
        env["HOME"] = FileManager.default.homeDirectoryForCurrentUser.path
        if env["PATH"] == nil {
            env["PATH"] = "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        }
        process.environment = env

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        states[entry] = RunState(process: process, pipe: pipe)

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor [weak self] in
                self?.states[entry]?.output.append(text)
            }
        }

        process.terminationHandler = { [weak self] proc in
            Task { @MainActor [weak self] in
                self?.states[entry]?.exitCode = proc.terminationStatus
                pipe.fileHandleForReading.readabilityHandler = nil
            }
        }

        do {
            try process.run()
        } catch {
            states[entry]?.output = "Failed to start: \(error.localizedDescription)"
            states[entry]?.exitCode = -1
        }
    }

    func stop(_ entry: CommandEntry) {
        guard let state = states[entry] else { return }
        if state.process.isRunning {
            // Kill the entire process group so child processes are also terminated
            let pid = state.process.processIdentifier
            kill(-pid, SIGTERM)
        }
        state.pipe.fileHandleForReading.readabilityHandler = nil
        states.removeValue(forKey: entry)
    }

    func stopAll() {
        for entry in states.keys {
            stop(entry)
        }
    }
}
