//
//  WineActivation.swift
//  WhiskyKit
//
//  This file is part of Whisky.
//
//  Whisky is free software: you can redistribute it and/or modify it under the terms
//  of the GNU General Public License as published by the Free Software Foundation,
//  either version 3 of the License, or (at your option) any later version.
//
//  Whisky is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
//  without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
//  See the GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License along with Whisky.
//  If not, see https://www.gnu.org/licenses/.
//

import AppKit

/// Brings a newly launched Windows program to the front.
///
/// macOS doesn't let a background process steal focus, so a game launched from Sili used to open behind other
/// windows. GTA San Andreas' screen picker looked like a hang, and fullscreen games didn't hide the menu bar and
/// Dock (Wine only hides them while the game is the active app). Sili, which is active when you press Play,
/// hands activation to the game's process once it shows a window.
public enum WineActivation {
    /// Wine processes that exist right now. Take this snapshot before launching.
    public static func currentWinePIDs() -> Set<pid_t> {
        Set(NSWorkspace.shared.runningApplications.filter(isWine).map(\.processIdentifier))
    }

    /// Waits for a Wine process that isn't in `existing` to show a window, then activates it.
    @MainActor
    public static func activateNewWindow(excluding existing: Set<pid_t>, timeout: Duration = .seconds(90)) async {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while clock.now < deadline {
            let candidates = Set(NSWorkspace.shared.runningApplications.filter(isWine).map(\.processIdentifier))
                .subtracting(existing)
            if let pid = windows(ownedBy: candidates).first?.pid,
               let app = NSRunningApplication(processIdentifier: pid) {
                NSApp.yieldActivation(to: app)
                app.activate()
                return
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
    }

    /// On-screen windows of Wine processes right now. Take this snapshot before asking a running program (such as
    /// Steam) to open a dialog.
    public static func currentWineWindowIDs() -> Set<CGWindowID> {
        Set(wineWindows().map(\.id))
    }

    /// Waits for a new window from any Wine process (for example Steam's uninstall dialog) and activates its owner.
    @MainActor
    public static func activateNewWindow(excludingWindows existing: Set<CGWindowID>,
                                         timeout: Duration = .seconds(30)) async {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while clock.now < deadline {
            if let window = wineWindows().first(where: { !existing.contains($0.id) }),
               let app = NSRunningApplication(processIdentifier: window.pid) {
                NSApp.yieldActivation(to: app)
                app.activate()
                return
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
    }

    /// For a launch that goes through Steam: brings each new Wine window to the front as it appears, so Steam's
    /// first-launch dialogs (launch options, EULA, "Launching…") aren't hidden behind other apps, and stops once a
    /// window from a new process that isn't part of Steam or Wine (the game itself) has been activated.
    /// Returns false if no game window appeared within `timeout`.
    @MainActor @discardableResult
    public static func followLaunch(existingPIDs: Set<pid_t>, existingWindows: Set<CGWindowID>,
                                    timeout: Duration = .seconds(120)) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        var handled = existingWindows
        while clock.now < deadline {
            for window in wineWindows() where !handled.contains(window.id) {
                handled.insert(window.id)
                guard let app = NSRunningApplication(processIdentifier: window.pid) else { continue }
                NSApp.yieldActivation(to: app)
                app.activate()
                // Steam starting up (when it wasn't running) also shows windows from new processes; keep following.
                if !existingPIDs.contains(window.pid), !isHelper(pid: window.pid) { return true }
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
        return false
    }

    /// Windows programs that show windows during a launch but aren't the game.
    static let helperExecutables: Set<String> = [
        "steam.exe", "steamwebhelper.exe", "steamwebhelper_real.exe", "steamservice.exe",
        "steamerrorreporter.exe", "explorer.exe"
    ]

    /// True if the Wine process is Steam or part of Wine itself.
    static func isHelper(pid: pid_t) -> Bool {
        windowsExecutableName(pid: pid).map { helperExecutables.contains($0) } ?? false
    }

    /// Wine sets a process's `argv[0]` to the Windows path of the program it runs (`C:\…\steam.exe`).
    /// Returns its lowercased file name, read the same way `ps` does.
    static func windowsExecutableName(pid: pid_t) -> String? {
        var mib = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0 else { return nil }
        return executableName(fromProcArgs: Array(buffer.prefix(size)))
    }

    /// Parses `KERN_PROCARGS2` output: `argc` (Int32), the executable path, NUL padding, then `argv[0]`.
    static func executableName(fromProcArgs bytes: [UInt8]) -> String? {
        var index = MemoryLayout<Int32>.size
        guard bytes.count > index else { return nil }
        while index < bytes.count, bytes[index] != 0 { index += 1 }
        while index < bytes.count, bytes[index] == 0 { index += 1 }
        let end = bytes[index...].firstIndex(of: 0) ?? bytes.count
        guard end > index, let argv0 = String(bytes: bytes[index..<end], encoding: .utf8) else { return nil }
        let name = argv0.split(whereSeparator: { $0 == "\\" || $0 == "/" }).last.map(String.init) ?? argv0
        return name.trimmingCharacters(in: .whitespaces).lowercased()
    }

    /// Normal on-screen windows (layer 0, larger than 100×100) owned by Wine processes.
    private static func wineWindows() -> [(id: CGWindowID, pid: pid_t)] {
        let pids = Set(NSWorkspace.shared.runningApplications.filter(isWine).map(\.processIdentifier))
        return windows(ownedBy: pids)
    }

    private static func windows(ownedBy pids: Set<pid_t>) -> [(id: CGWindowID, pid: pid_t)] {
        guard !pids.isEmpty,
              let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                    kCGNullWindowID) as? [[String: Any]] else { return [] }
        return list.compactMap { window in
            guard let pid = window[kCGWindowOwnerPID as String] as? pid_t, pids.contains(pid),
                  let id = window[kCGWindowNumber as String] as? CGWindowID,
                  (window[kCGWindowLayer as String] as? Int) == 0,
                  let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
                  (bounds["Width"] ?? 0) > 100, (bounds["Height"] ?? 0) > 100 else { return nil }
            return (id, pid)
        }
    }

    private static func isWine(_ app: NSRunningApplication) -> Bool {
        app.executableURL?.path(percentEncoded: false).contains("/Libraries/Wine/") ?? false
    }
}
