//
//  MatchClient.swift
//  Hunch — Wick 3.0 live multiplayer
//
//  The live-match connection: a thin, typed wrapper over URLSessionWebSocketTask.
//  Mirrors the web client (wick-web/src/net/client.ts): open WSS /match, send
//  queue/guess/ask/heartbeat, surface paired/state/result/scored/answer/
//  opponentLeft/error via a delegate. The UI never touches raw frames.
//
//  Offline-safe spirit (C3): every failure path calls the delegate's close/error
//  rather than throwing into the UI, so the app can always fall back gracefully.
//  All delegate callbacks are delivered on the main actor.
//

import Foundation

@MainActor
protocol MatchClientDelegate: AnyObject {
    func matchClientDidOpen()
    func matchClient(didReceive frame: ServerFrame)
    func matchClientDidClose(clean: Bool)
    func matchClient(didError message: String)
}

final class MatchClient: NSObject {
    weak var delegate: MatchClientDelegate?

    private let base: URL
    private let kid: String
    private var task: URLSessionWebSocketTask?
    private var session: URLSession!
    private var heartbeat: Task<Void, Never>?
    private var closedByUs = false

    init(base: URL = LiveConfig.serverBase, kid: String = LiveConfig.kid) {
        self.base = base
        self.kid = kid
        super.init()
        // A delegate session so we get precise open/close callbacks.
        self.session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }

    // MARK: Lifecycle

    func connect() {
        closedByUs = false
        var comps = URLComponents(
            url: base.appendingPathComponent("match"),
            resolvingAgainstBaseURL: false
        )
        comps?.queryItems = [URLQueryItem(name: "kid", value: kid)]
        guard let url = comps?.url else {
            emitError("Couldn't build the connection URL.")
            return
        }
        let task = session.webSocketTask(with: url)
        self.task = task
        receiveNext()          // arm the receive loop before resuming
        task.resume()
    }

    func close() {
        closedByUs = true
        stopHeartbeat()
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    // MARK: Send API (mirrors the web client)

    /// Queue for a match. With `friendCode`, `create` declares intent (3.1 links):
    /// `true` = host a fresh invite (server rejects a colliding code with
    /// `code_taken`); `false` = join an existing one (`no_such_invite` if it's dead);
    /// nil = legacy first-hosts/second-joins.
    func queue(mode: MatchMode, friendCode: String? = nil, create: Bool? = nil) {
        send(.queue(mode: mode, friendCode: friendCode, create: create))
    }

    func guess(_ word: String, warmth: Double? = nil) {
        send(.guess(word, warmth: warmth))
    }

    func question(warmth: Double) {
        send(.question(warmth: warmth))
    }

    /// Ask Wick a yes/no question mid-match; the server answers on the room secret
    /// and replies with an `answer` frame.
    func ask(_ question: String) {
        send(.ask(question))
    }

    // MARK: Internals

    private func send(_ frame: ClientFrame) {
        guard let task, let text = frame.encoded() else { return }
        task.send(.string(text)) { [weak self] error in
            guard let self, let error else { return }
            Task { @MainActor in self.delegate?.matchClient(didError: error.localizedDescription) }
        }
    }

    private func receiveNext() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                self.stopHeartbeat()
                if !self.closedByUs {
                    Task { @MainActor in self.delegate?.matchClient(didError: error.localizedDescription) }
                }
            case .success(let message):
                switch message {
                case .string(let text):
                    if let frame = ServerFrame.parse(text) {
                        Task { @MainActor in self.delegate?.matchClient(didReceive: frame) }
                    }
                case .data:
                    break // we only speak JSON text frames
                @unknown default:
                    break
                }
                self.receiveNext() // keep listening
            }
        }
    }

    private func emitError(_ message: String) {
        Task { @MainActor in self.delegate?.matchClient(didError: message) }
    }

    private func startHeartbeat() {
        stopHeartbeat()
        heartbeat = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000) // 15s
                guard !Task.isCancelled else { break }
                self?.send(.heartbeat)
            }
        }
    }

    private func stopHeartbeat() {
        heartbeat?.cancel()
        heartbeat = nil
    }
}

// MARK: - URLSessionWebSocketDelegate (open/close)

extension MatchClient: URLSessionWebSocketDelegate {
    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol proto: String?
    ) {
        startHeartbeat()
        Task { @MainActor in self.delegate?.matchClientDidOpen() }
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        stopHeartbeat()
        let clean = closeCode == .normalClosure || closeCode == .goingAway
        Task { @MainActor in self.delegate?.matchClientDidClose(clean: clean) }
    }
}
