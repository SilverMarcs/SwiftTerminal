import Foundation

/// Thrown when the Claude Agent SDK is not installed globally.
struct SDKNotInstalledError: LocalizedError {
    var errorDescription: String? {
        "Claude Agent SDK not found. Install it with:\n\nnpm install -g @anthropic-ai/claude-agent-sdk"
    }
}

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

    /// Resolve the global npm `node_modules` path by running `npm root -g`.
    /// Returns `nil` if npm is not found or the SDK package isn't installed there.
    private static func resolveGlobalNodeModules(nodePath: String) -> String? {
        let task = Process()
        task.executableURL = URL(filePath: nodePath)
        task.arguments = ["-e", "process.stdout.write(require('child_process').execSync('npm root -g').toString().trim())"]

        var env = ProcessInfo.processInfo.environment
        let extraPaths = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        if let existingPath = env["PATH"] {
            env["PATH"] = extraPaths + ":" + existingPath
        } else {
            env["PATH"] = extraPaths
        }
        task.environment = env

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let globalRoot = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !globalRoot.isEmpty else { return nil }

            // Verify the SDK package actually exists at this location
            let sdkPath = (globalRoot as NSString).appendingPathComponent("@anthropic-ai/claude-agent-sdk")
            if FileManager.default.fileExists(atPath: sdkPath) {
                return globalRoot
            }
            return nil
        } catch {
            return nil
        }
    }

    /// Start the bridge process.
    /// - Parameter workingDirectory: The user's project directory to run in.
    /// - Returns: An async stream of JSON lines from stdout.
    /// - Throws: ``SDKNotInstalledError`` if the SDK is not globally installed.
    func start(workingDirectory: String) throws -> AsyncStream<String> {
        let proc = Process()

        // Find node executable
        var foundNodePath: String?
        for nodePath in ["/opt/homebrew/bin/node", "/usr/local/bin/node"] {
            if FileManager.default.fileExists(atPath: nodePath) {
                proc.executableURL = URL(filePath: nodePath)
                foundNodePath = nodePath
                break
            }
        }

        guard let nodePath = foundNodePath else {
            throw SDKNotInstalledError()
        }

        // Resolve the global npm node_modules where the SDK is installed
        guard let globalNodeModules = Self.resolveGlobalNodeModules(nodePath: nodePath) else {
            throw SDKNotInstalledError()
        }

        let bridgeScript = Self.bridgeScriptPath
        let resourcesDir = (bridgeScript as NSString).deletingLastPathComponent

        // ESM ignores NODE_PATH, so symlink node_modules next to the bridge script
        // so that Node resolves bare specifiers relative to the script location.
        let symlinkPath = (resourcesDir as NSString).appendingPathComponent("node_modules")
        let fm = FileManager.default
        if !fm.fileExists(atPath: symlinkPath) {
            try? fm.createSymbolicLink(atPath: symlinkPath, withDestinationPath: globalNodeModules)
        }

        proc.arguments = [bridgeScript]

        var env = ProcessInfo.processInfo.environment
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
