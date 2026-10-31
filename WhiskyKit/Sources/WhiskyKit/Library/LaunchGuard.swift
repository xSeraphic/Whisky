//
//  LaunchGuard.swift
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

import Foundation

/// Ignores repeat launches of the same program in quick succession. Double-clicking a pinned program twice used to
/// start two copies; for Steam under Wine that means two clients, and games then fail to connect to Steam.
public final class LaunchGuard: @unchecked Sendable {
    public static let shared = LaunchGuard()
    /// Repeat launches within this many seconds are ignored.
    public static let interval: TimeInterval = 10

    private let lock = NSLock()
    private var lastLaunch: [String: Date] = [:]

    public init() {}

    /// Returns true and records the launch, unless the same key was launched less than `interval` seconds ago.
    public func shouldLaunch(_ key: String, interval: TimeInterval = LaunchGuard.interval, now: Date = Date()) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if let last = lastLaunch[key], now.timeIntervalSince(last) < interval { return false }
        lastLaunch[key] = now
        return true
    }

    /// Forgets a launch, for example because it failed, so trying again works straight away.
    public func forget(_ key: String) {
        lock.lock()
        defer { lock.unlock() }
        lastLaunch[key] = nil
    }
}
