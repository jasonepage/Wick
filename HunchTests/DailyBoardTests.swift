//
//  DailyBoardTests.swift
//  HunchTests
//
//  3.6: the race board's pure parts. Formatting and reading the server's JSON.
//

import Foundation
import Testing
@testable import Hunch

struct DailyBoardTests {

    @Test func formatsTimes() {
        #expect(BoardFormat.time(ms: 0) == "0:00")
        #expect(BoardFormat.time(ms: 250_000) == "4:10")
        #expect(BoardFormat.time(ms: 59_999) == "0:59")
        #expect(BoardFormat.time(ms: 3_725_000) == "1:02:05")
    }

    @Test func flags() {
        #expect(BoardFormat.flag("es") == "🇪🇸")
        #expect(BoardFormat.flag("zh") == "🇨🇳")
        #expect(BoardFormat.flag("en") == "🇺🇸")
    }

    @Test func readsTheServerBoard() throws {
        let json = """
        {"n":1419,"total":2,
         "top":[{"rank":1,"id":"a1b2c3d4","name":"Violet Otter","g":6,"h":0,"ms":250000,"lang":"en"},
                {"rank":2,"id":"e5f6a7b8","name":"Swift Heron","g":5,"h":1,"ms":90000,"lang":"es"}],
         "me":{"rank":2,"id":"e5f6a7b8","name":"Swift Heron","g":5,"h":1,"ms":90000,"lang":"es"}}
        """
        let snap = try JSONDecoder().decode(BoardSnapshot.self, from: Data(json.utf8))
        #expect(snap.total == 2)
        #expect(snap.top.map(\.name) == ["Violet Otter", "Swift Heron"])
        #expect(snap.me?.rank == 2)
    }

    @Test func readsAGiveUp() throws {
        let json = #"{"n":1420,"total":1,"top":[{"rank":1,"id":"a1b2c3d4","name":"Violet Otter","g":3,"h":0,"ms":40000,"lang":"en","gu":true}]}"#
        let snap = try JSONDecoder().decode(BoardSnapshot.self, from: Data(json.utf8))
        #expect(snap.top.first?.gaveUp == true)
    }

    @Test func readsABoardWithoutMe() throws {
        let json = #"{"n":1419,"total":0,"top":[]}"#
        let snap = try JSONDecoder().decode(BoardSnapshot.self, from: Data(json.utf8))
        #expect(snap.me == nil)
        #expect(snap.top.isEmpty)
    }
}
