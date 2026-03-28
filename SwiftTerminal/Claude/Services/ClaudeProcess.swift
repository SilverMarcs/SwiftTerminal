import Foundation

/// Manages the Node.js bridge process that wraps the Claude Agent SDK.
/// Provides a persistent connection for multi-turn sessions with
/// rewind, session listing, and other SDK features.
final class ClaudeProcess {
    private var process: Process?
    private var stdinHandle: FileHandle?
    private var lineContinuation: AsyncStream<String>.Continuation?

    var isRunning: Bool { process?.isRunning ?? false }

    /// Bridge script is bundled in the app's Resources.
    private static var bridgeScriptPath: String {
        Bundle.main.path(forResource: "claude-bridge", ofType: "mjs")!
    }

    /// Start the bridge process.
    /// - Parameter workingDirectory: The user's project directory to run in.
    /// - Returns: An async stream of JSON lines from stdout.
    func start(workingDirectory: String) throws -> AsyncStream<String> {
        let proc = Process()

        // Find node executable
        for nodePath in ["/opt/homebrew/bin/node", "/usr/local/bin/node"] {
            if FileManager.default.fileExists(atPath: nodePath) {
                proc.executableURL = URL(filePath: nodePath)
                break
            }
        }

        let bridgeScript = Self.bridgeScriptPath
        let resourcesDir = Bundle.main.resourceURL!.path

        proc.arguments = [bridgeScript]

        // Environment: node_modules is bundled in Resources
        var env = ProcessInfo.processInfo.environment
        env["NODE_PATH"] = resourcesDir + "/node_modules"
        let extraPaths = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        if let existingPath = env["PATH"] {
            env["PATH"] = extraPaths + ":" + existingPath
        } else {
            env["PATH"] = extraPaths
        }
        env["TERM"] = "xterm-256color"
        env["HOME"] = env["HOME"] ?? NSHomeDirectory()
        proc.environment = env
        proc.currentDirectoryURL = URL(filePath: workingDirectory)

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        proc.standardInput = stdinPipe
        proc.standardOutput = stdoutPipe
        proc.standardError = stderrPipe

        self.process = proc
        self.stdinHandle = stdinPipe.fileHandleForWriting

        // Log stderr for debugging
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let str = String(data: data, encoding: .utf8), !str.isEmpty {
                print("[Claude Bridge stderr]", str)
            }
        }

        try proc.run()

        let handle = stdoutPipe.fileHandleForReading
        let stream = AsyncStream<String> { [weak self] continuation in
            self?.lineContinuation = continuation

            // Read stdout on a background thread
            Thread.detachNewThread {
                var buffer = Data()
                let newline = UInt8(ascii: "\n")

                while true {
                    let chunk = handle.availableData
                    if chunk.isEmpty { break }

                    buffer.append(chunk)

                    while let idx = buffer.firstIndex(of: newline) {
                        let lineData = buffer[buffer.startIndex..<idx]
                        buffer = Data(buffer[buffer.index(after: idx)...])
                        if let line = String(data: lineData, encoding: .utf8), !line.isEmpty {
                            continuation.yield(line)
                        }
                    }
                }

                if !buffer.isEmpty, let line = String(data: buffer, encoding: .utf8), !line.isEmpty {
                    continuation.yield(line)
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                // Cleanup handled by terminate()
            }
        }

        return stream
    }

    /// Send a JSON command to the bridge via stdin.
    func sendCommand(_ command: String, params: [String: Any] = [:]) {
        guard let handle = stdinHandle else { return }

        var obj: [String: Any] = ["command": command]
        if !params.isEmpty {
            obj["params"] = params
        }

        guard let data = try? JSONSerialization.data(withJSONObject: obj),
              let jsonLine = String(data: data, encoding: .utf8) else { return }

        let lineData = (jsonLine + "\n").data(using: .utf8)!
        handle.write(lineData)
    }

    /// Terminate the bridge process.
    func terminate() {
        stdinHandle?.closeFile()
        stdinHandle = nil
        if let proc = process, proc.isRunning {
            proc.terminate()
        }
        process = nil
        lineContinuation?.finish()
        lineContinuation = nil
    }
}
