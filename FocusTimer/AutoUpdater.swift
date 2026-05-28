import Foundation
import AppKit

@MainActor
final class AutoUpdater: ObservableObject {
    static let shared = AutoUpdater()

    enum Phase: Equatable {
        case idle
        case downloading(Double)   // 0…1
        case installing
        case failed(String)
    }

    @Published var phase: Phase = .idle

    private init() {}

    func startUpdate(from urlString: String) {
        guard case .idle = phase, let url = URL(string: urlString) else { return }
        phase = .downloading(0)
        Task { await download(url: url) }
    }

    private func download(url: URL) async {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("FocusTimer-update.dmg")
        try? FileManager.default.removeItem(at: tmp)

        do {
            let (asyncBytes, response) = try await URLSession.shared.bytes(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                phase = .failed("Download failed"); return
            }

            let total = response.expectedContentLength
            var received: Int64 = 0
            var buffer = Data()
            buffer.reserveCapacity(total > 0 ? Int(total) : 4_000_000)

            for try await byte in asyncBytes {
                buffer.append(byte)
                received += 1
                if total > 0, received % 32_768 == 0 {
                    phase = .downloading(Double(received) / Double(total))
                }
            }

            try buffer.write(to: tmp)
        } catch {
            phase = .failed("Download failed: \(error.localizedDescription)")
            return
        }

        phase = .installing
        await install(dmg: tmp)
    }

    private func install(dmg: URL) async {
        let mountPoint = URL(fileURLWithPath: "/tmp/FocusTimer-update-mnt")
        try? FileManager.default.removeItem(at: mountPoint)
        try? FileManager.default.createDirectory(at: mountPoint, withIntermediateDirectories: true)

        guard run("/usr/bin/hdiutil", ["attach", dmg.path, "-readonly", "-nobrowse",
                                       "-noautoopen", "-mountpoint", mountPoint.path]) == 0 else {
            phase = .failed("Could not mount update"); return
        }

        let src = mountPoint.appendingPathComponent("FocusTimer.app")
        let dst = URL(fileURLWithPath: "/Applications/FocusTimer.app")
        let fm  = FileManager.default

        do {
            if fm.fileExists(atPath: dst.path) { try fm.removeItem(at: dst) }
            try fm.copyItem(at: src, to: dst)
        } catch {
            _ = run("/usr/bin/hdiutil", ["detach", mountPoint.path, "-force"])
            phase = .failed("Could not replace app — try dragging manually")
            return
        }

        _ = run("/usr/bin/hdiutil", ["detach", mountPoint.path, "-force"])

        // Relaunch updated app then quit this instance
        let relaunch = Process()
        relaunch.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        relaunch.arguments = ["-n", "/Applications/FocusTimer.app"]
        try? relaunch.run()
        NSApplication.shared.terminate(nil)
    }

    @discardableResult
    private func run(_ exe: String, _ args: [String]) -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: exe)
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError  = FileHandle.nullDevice
        try? p.run()
        p.waitUntilExit()
        return p.terminationStatus
    }
}
