import Foundation

/// Controls charging via the `batt` CLI tool.
final class ChargeController {
    
    let battBinaryPath: String
    
    init() {
        let candidates = ["/opt/homebrew/bin/batt", "/usr/local/bin/batt"]
        battBinaryPath = candidates.first { FileManager.default.fileExists(atPath: $0) } ?? "/opt/homebrew/bin/batt"
    }
    
    /// Set charge limit percentage (10-100). 100 turns off charge limit.
    @discardableResult
    func setChargeLimit(_ percentage: Int) -> Bool {
        let clamped = max(10, min(100, percentage))
        return runBatt(args: ["limit", String(clamped)])
    }
    
    /// Disable power adapter (runs on battery even when physically connected).
    @discardableResult
    func disableAdapter() -> Bool {
        return runBatt(args: ["adapter", "disable"])
    }
    
    /// Re-enable power adapter.
    @discardableResult
    func enableAdapter() -> Bool {
        return runBatt(args: ["adapter", "enable"])
    }
    
    /// Check whether batt daemon is running.
    func isDaemonRunning() -> Bool {
        let output = runBattWithOutput(args: ["status"]) ?? ""
        return !output.contains("daemon not running") && !output.contains("Error")
    }
    
    /// Restore all charging settings back to macOS defaults (limit 100 and adapter enabled).
    func restoreFactoryDefaults() {
        _ = enableAdapter()
        _ = setChargeLimit(100)
    }
    
    // MARK: - Private Execution Helpers
    
    @discardableResult
    private func runBatt(args: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: battBinaryPath)
        process.arguments = args
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    private func runBattWithOutput(args: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: battBinaryPath)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}
