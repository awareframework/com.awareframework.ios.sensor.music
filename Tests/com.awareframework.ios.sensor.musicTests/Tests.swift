import XCTest

@testable import com_awareframework_ios_sensor_music

class Tests: XCTestCase {

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testMusicData() {
        var data = MusicData()
        let dict = data.toDictionary()
        XCTAssertEqual(dict["playbackState"] as! Int, -1)
        XCTAssertEqual(dict["title"] as! String, "")
        XCTAssertEqual(dict["artist"] as! String, "")

        data.playbackState = 1
        data.title = "Test Song"
        data.artist = "Test Artist"
        let newDict = data.toDictionary()
        XCTAssertEqual(newDict["playbackState"] as! Int, 1)
        XCTAssertEqual(newDict["title"] as! String, "Test Song")
        XCTAssertEqual(newDict["artist"] as! String, "Test Artist")
    }

    func testMusicDataFromDictionary() {
        let dict: [String: Any] = [
            "title": "My Song",
            "artist": "My Artist",
            "album": "My Album",
            "genre": "Rock",
            "duration": 240.0,
            "playbackState": 1,
            "playbackRate": 1.0,
        ]
        let data = MusicData(dict)
        XCTAssertEqual(data.title, "My Song")
        XCTAssertEqual(data.artist, "My Artist")
        XCTAssertEqual(data.album, "My Album")
        XCTAssertEqual(data.genre, "Rock")
        XCTAssertEqual(data.duration, 240.0)
        XCTAssertEqual(data.playbackState, 1)
        XCTAssertEqual(data.playbackRate, 1.0)
    }

    func testControllers() {
        let sensor = MusicSensor()

        let expectSetLabel = expectation(description: "set label")
        let newLabel = "test_label"
        let labelObserver = NotificationCenter.default.addObserver(
            forName: .actionAwareMusicSetLabel, object: nil, queue: .main
        ) { notification in
            if let userInfo = notification.userInfo as? [String: String] {
                XCTAssertEqual(userInfo[MusicSensor.EXTRA_LABEL], newLabel)
            }
            expectSetLabel.fulfill()
        }
        sensor.set(label: newLabel)
        wait(for: [expectSetLabel], timeout: 5)
        NotificationCenter.default.removeObserver(labelObserver)

        let expectSync = expectation(description: "sync")
        let syncObserver = NotificationCenter.default.addObserver(
            forName: .actionAwareMusicSync, object: nil, queue: .main
        ) { _ in
            expectSync.fulfill()
        }
        sensor.sync()
        wait(for: [expectSync], timeout: 5)
        NotificationCenter.default.removeObserver(syncObserver)

        let expectStart = expectation(description: "start")
        let startObserver = NotificationCenter.default.addObserver(
            forName: .actionAwareMusicStart, object: nil, queue: .main
        ) { _ in
            expectStart.fulfill()
        }
        sensor.start()
        wait(for: [expectStart], timeout: 5)
        NotificationCenter.default.removeObserver(startObserver)

        let expectStop = expectation(description: "stop")
        let stopObserver = NotificationCenter.default.addObserver(
            forName: .actionAwareMusicStop, object: nil, queue: .main
        ) { _ in
            expectStop.fulfill()
        }
        sensor.stop()
        wait(for: [expectStop], timeout: 5)
        NotificationCenter.default.removeObserver(stopObserver)
    }

    func testSyncModule() throws {
        throw XCTSkip("Sync integration test requires external server configuration and is excluded from unit tests.")
    }
}
