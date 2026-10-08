//
//  DuelResultStore.swift
//  Hunch
//
//  Remembers YOUR finished duel results (keyed by language + word) so that when a
//  friend pastes their result code, we can render a real head-to-head. Tiny and
//  local: results are stored as their own compact codes in UserDefaults.
//

import Foundation

enum DuelResultStore {
    private static let key = "hunch.duel.myResults"

    static func save(_ result: DuelResult) {
        guard let code = DuelCode.encode(result) else { return }
        var dict = UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:]
        dict[storageKey(result.language, result.wordIndex)] = code
        UserDefaults.standard.set(dict, forKey: key)
    }

    /// Your own result for a given duel word, if you've played it.
    static func myResult(language: GameLanguage, wordIndex: Int) -> DuelResult? {
        let dict = UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:]
        guard let code = dict[storageKey(language, wordIndex)] else { return nil }
        return DuelCode.decodeResult(code)
    }

    private static func storageKey(_ language: GameLanguage, _ wordIndex: Int) -> String {
        "\(language.rawValue):\(wordIndex)"
    }
}
