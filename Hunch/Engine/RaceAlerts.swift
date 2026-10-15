// SPDX-License-Identifier: MPL-2.0
//
//  RaceAlerts.swift
//  Hunch
//
//  Race alerts: pushes from the Wick server when there is someone to race.
//  The player picks which kinds in Settings:
//
//    waiting  someone is waiting for a live race
//    busy     several people are waiting at once
//    surge    far more people are playing than usual for this time of week
//
//  This is the app's only use of Apple push. iOS hands us a device token; we
//  send it to the server (POST /push/register) with the player's live id, the
//  language they play in, and the kinds they want. The server keeps that in
//  memory, so we send it again every time the app comes to the foreground. An
//  empty kinds list tells the server to forget the phone.
//
//  Needs the Push Notifications capability on the App ID and the
//  aps-environment entitlement (Hunch.entitlements). Without them iOS never
//  calls back with a token and the toggles simply do nothing, which is the
//  failure mode we want: nothing breaks.
//

import Foundation
import UIKit
import UserNotifications

@MainActor
@Observable
final class RaceAlerts {
    static let shared = RaceAlerts()

    enum Kind: String, CaseIterable {
        case waiting, busy, surge
        var storageKey: String { "wick.alerts.\(rawValue)" }
    }

    /// Called when the player taps a race alert: open the live race screen.
    var openRace: (() -> Void)?

    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private let tokenKey = "wick.alerts.token"
    @ObservationIgnored private var lastSent: String?

    /// The kinds the player turned on. Observed, so Settings redraws when a
    /// denied permission flips a toggle back off.
    private(set) var kinds: Set<Kind>

    private init() {
        kinds = Set(Kind.allCases.filter { UserDefaults.standard.bool(forKey: $0.storageKey) })
    }

    // MARK: - Preferences

    func wants(_ kind: Kind) -> Bool {
        kinds.contains(kind)
    }

    var wantedKinds: [Kind] { Kind.allCases.filter { kinds.contains($0) } }

    private func store(_ kind: Kind, _ on: Bool) {
        if on { kinds.insert(kind) } else { kinds.remove(kind) }
        defaults.set(on, forKey: kind.storageKey)
    }

    /// Turn a kind on or off. Turning one on asks for permission and a device
    /// token; every change is sent to the server.
    func set(_ kind: Kind, on: Bool) {
        store(kind, on)
        if on {
            Task {
                let ok = await HunchNotifications.requestPermission()
                if ok {
                    requestToken()
                    sync()
                } else {
                    store(kind, false)
                }
            }
        } else {
            sync()
        }
    }

    /// The app came to the foreground: make sure iOS still has a token for us
    /// (they can change) and tell the server what this phone wants.
    func refresh(lang: String = GameLanguage.storedUI.rawValue) {
        if !kinds.isEmpty { requestToken() }
        sync(lang: lang)
    }

    // MARK: - Device token

    /// Ask iOS for a push token. The answer comes back through the app
    /// delegate as `tokenReceived`. NEVER call this from `sync` or from
    /// `tokenReceived`: on a release build iOS answers at once, and asking
    /// again from the answer spins forever (that was a crash in 3.5's first
    /// TestFlight build).
    private func requestToken() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    /// iOS gave us a token (AppDelegate). A changed token is sent again.
    func tokenReceived(_ data: Data) {
        let hex = data.map { String(format: "%02x", $0) }.joined()
        if hex != token {
            defaults.set(hex, forKey: tokenKey)
            lastSent = nil
        }
        sync()
    }

    private var token: String? { defaults.string(forKey: tokenKey) }

    // MARK: - Server

    /// Tell the server what this phone wants. Safe to call often: it skips a
    /// repeat of what was last sent, and it never asks iOS for anything.
    func sync(lang: String = GameLanguage.storedUI.rawValue) {
        guard let token, let base = LiveConfig.httpBase else { return }
        let kinds = wantedKinds.map(\.rawValue)
        let body: [String: Any] = ["token": token, "kid": LiveConfig.kid, "lang": lang, "kinds": kinds]
        let signature = "\(token)|\(lang)|\(kinds.joined(separator: ","))"
        guard signature != lastSent else { return }
        // Marked as sent before the request goes out, so a slow or failing
        // server can never cause a second request for the same thing.
        lastSent = signature
        var req = URLRequest(url: base.appendingPathComponent("push/register"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 10
        Task {
            do {
                let (_, response) = try await URLSession.shared.data(for: req)
                if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                    lastSent = nil   // the next foreground tries again
                }
            } catch {
                lastSent = nil       // offline or the server is asleep: try again next time
            }
        }
    }

    // MARK: - Links

    /// The push payload carries "wick://race": open the live race screen.
    static func isRaceLink(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "wick" && url.host?.lowercased() == "race"
            && url.pathComponents.filter({ $0 != "/" }).isEmpty
    }
}

/// Receives the device token and notification taps. Hooked up in HunchApp.
final class RaceAlertsAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in RaceAlerts.shared.tokenReceived(deviceToken) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Simulator, or the capability is missing. The toggles stay harmless.
    }

    /// Show a race alert even while the app is open.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    /// A tapped alert opens the live race screen.
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let link = response.notification.request.content.userInfo["link"] as? String
        if let link, let url = URL(string: link), RaceAlerts.isRaceLink(url) {
            Task { @MainActor in RaceAlerts.shared.openRace?() }
        }
        completionHandler()
    }
}
