import XCTest
@testable import Matrix

@MainActor
final class NotesStoreTests: XCTestCase {
    private var url: URL!

    override func setUp() {
        url = FileManager.default.temporaryDirectory.appending(path: "notes-\(UUID()).json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: url)
    }

    func testNewestFirstAndPersisted() {
        let store = NotesStore(fileURL: url)
        store.add("first")
        store.add("  second\nline  ")
        XCTAssertEqual(store.notes.map(\.text), ["second\nline", "first"])

        let reloaded = NotesStore(fileURL: url)
        XCTAssertEqual(reloaded.notes, store.notes)
    }

    func testBlankNotesAreIgnored() {
        let store = NotesStore(fileURL: url)
        store.add("   \n ")
        XCTAssertTrue(store.notes.isEmpty)
    }

    func testRemove() {
        let store = NotesStore(fileURL: url)
        store.add("a")
        store.add("b")
        store.remove(store.notes[0].id)
        XCTAssertEqual(NotesStore(fileURL: url).notes.map(\.text), ["a"])
    }
}

final class FormatTests: XCTestCase {
    func testTimeIsAlways24Hour() {
        let date = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 30, hour: 18, minute: 5))!
        XCTAssertEqual(Format.time(date), "18:05")
    }

    func testUptime() {
        // The test host shares the app's defaults, so keep the user's language choice intact.
        let saved = UserDefaults.standard.string(forKey: AppLanguage.storageKey)
        defer { UserDefaults.standard.set(saved, forKey: AppLanguage.storageKey) }

        UserDefaults.standard.set("en", forKey: AppLanguage.storageKey)
        XCTAssertEqual(Format.uptime(3 * 86400 + 14 * 3600 + 59), "3d 14h")
        XCTAssertEqual(Format.uptime(5 * 3600 + 12 * 60), "5h 12m")
        XCTAssertEqual(Format.uptime(42 * 60), "42m")
        XCTAssertEqual(Format.rpm(2150), "2,150")

        UserDefaults.standard.set("tr", forKey: AppLanguage.storageKey)
        XCTAssertEqual(Format.rpm(2150), "2.150")
        XCTAssertEqual(Format.uptime(3 * 86400 + 14 * 3600 + 59), "3g 14s")
        XCTAssertEqual(Format.uptime(42 * 60), "42dk")
    }

    func testLanguageLookupIgnoresSystemLanguage() {
        XCTAssertEqual(AppLanguage.tr.string("BLACK SUN"), "KARA GÜNEŞ")
        XCTAssertEqual(AppLanguage.en.string("BLACK SUN"), "BLACK SUN")
    }

    func testUnits() {
        XCTAssertEqual(Format.memory(11.2 * 1_073_741_824), "11.2")
        XCTAssertEqual(Format.memoryTotal(25_769_803_776), "24")
        XCTAssertEqual(Format.disk(494_000_000_000), "494")
        XCTAssertEqual(Format.percent(0.625), "63")
        XCTAssertEqual(Format.temperature(nil), "—")
    }
}

final class SensorTests: XCTestCase {
    func testMemoryBreakdownFitsInPhysicalMemory() throws {
        let reading = try XCTUnwrap(MemorySampler().sample())
        XCTAssertGreaterThan(reading.used, 0)
        XCTAssertLessThanOrEqual(reading.used, reading.total)
    }

    func testDisk() throws {
        let disk = try XCTUnwrap(DiskSampler.sample())
        XCTAssertGreaterThan(disk.total, disk.free)
    }

    func testSMCFourCCRoundTrip() {
        XCTAssertEqual(SMC.string(from: SMC.fourCC("TH0x")), "TH0x")
    }
}

@MainActor
final class LuckStoreTests: XCTestCase {
    private func store() -> LuckStore {
        LuckStore(defaults: UserDefaults(suiteName: "matrix-tests-\(UUID())")!)
    }

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute))!
    }

    func testSameCardAllDay() {
        let luck = store()
        XCTAssertNil(luck.card(on: date(30, 8)))
        let first = luck.drawToday(on: date(30, 8))
        XCTAssertTrue(first.isNew)
        let again = luck.drawToday(on: date(30, 23, 59))
        XCTAssertFalse(again.isNew)
        XCTAssertEqual(again.card, first.card)
    }

    func testResetsAtMidnight() {
        let luck = store()
        _ = luck.drawToday(on: date(29, 23, 59))
        XCTAssertNil(luck.card(on: date(30, 0)))
        XCTAssertTrue(luck.drawToday(on: date(30, 0)).isNew)
    }

    func testPersists() {
        let defaults = UserDefaults(suiteName: "matrix-tests-\(UUID())")!
        let card = LuckStore(defaults: defaults).drawToday(on: date(30, 12)).card
        XCTAssertEqual(LuckStore(defaults: defaults).card(on: date(30, 18)), card)
    }

    func testCountdownToMidnight() {
        XCTAssertEqual(LuckOverlay.countdown(from: date(30, 19, 4)), "04:56:00")
    }
}

final class HysteresisTests: XCTestCase {
    func testIgnoresJitterBelowOnePoint() {
        var h = Hysteresis()
        XCTAssertEqual(h.update(58.4), 58)
        XCTAssertEqual(h.update(58.6), 58)
        XCTAssertEqual(h.update(57.2), 58)
        XCTAssertEqual(h.update(59.1), 59)
        XCTAssertEqual(h.update(58.1), 59)
        XCTAssertEqual(h.update(57.8), 58)
        XCTAssertNil(h.update(nil))
    }
}
