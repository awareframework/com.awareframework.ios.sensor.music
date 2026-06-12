import Foundation
import GRDB
import com_awareframework_ios_core

public struct MusicData: BaseDbModelSQLite {
    public static let databaseTableName = "ios_music"
    public static let TABLE_NAME = databaseTableName

    public var timezone: Int = AwareUtils.getTimeZone()
    public var os: String = "iOS"
    public var jsonVersion: Int = 1

    public var id: Int64?
    public var timestamp: Int64
    public var deviceId: String = AwareUtils.getCommonDeviceId()
    public var label: String

    /// Song title
    public var title: String = ""
    /// Artist name
    public var artist: String = ""
    /// Album title
    public var album: String = ""
    /// Genre
    public var genre: String = ""
    /// Track duration in seconds
    public var duration: Double = -1
    /// Playback position at the event time in seconds
    public var position: Double = -1
    /// MPMusicPlaybackState raw value: stopped=0, playing=1, paused=2, interrupted=3, seekingForward=4, seekingBackward=5
    public var playbackState: Int = -1
    /// Current playback rate (0.0 = paused, 1.0 = normal speed)
    public var playbackRate: Double = -1

    public init(timestamp: Int64 = Int64(Date().timeIntervalSince1970 * 1000), label: String = "") {
        self.timestamp = timestamp
        self.label = label
    }

    public init(_ dict: [String: Any]) {
        self.id = dict["id"] as? Int64
        self.timestamp = dict["timestamp"] as? Int64 ?? Int64(Date().timeIntervalSince1970 * 1000)
        self.deviceId = dict["deviceId"] as? String ?? AwareUtils.getCommonDeviceId()
        self.label = dict["label"] as? String ?? ""
        self.title = dict["title"] as? String ?? ""
        self.artist = dict["artist"] as? String ?? ""
        self.album = dict["album"] as? String ?? ""
        self.genre = dict["genre"] as? String ?? ""
        self.duration = dict["duration"] as? Double ?? -1
        self.position = dict["position"] as? Double ?? -1
        self.playbackState = dict["playbackState"] as? Int ?? -1
        self.playbackRate = dict["playbackRate"] as? Double ?? -1
    }

    public func toDictionary() -> [String: Any] {
        [
            "id": self.id ?? -1,
            "timestamp": self.timestamp,
            "deviceId": self.deviceId,
            "label": self.label,
            "title": self.title,
            "artist": self.artist,
            "album": self.album,
            "genre": self.genre,
            "duration": self.duration,
            "position": self.position,
            "playbackState": self.playbackState,
            "playbackRate": self.playbackRate,
            "os": self.os,
            "timezone": self.timezone,
            "jsonVersion": self.jsonVersion,
        ]
    }

    public static func createTable(queue: DatabaseQueue) throws {
        try queue.write { db in
            try db.create(table: databaseTableName, ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("timestamp", .integer).notNull()
                t.column("deviceId", .text).notNull()
                t.column("label", .text)
                t.column("title", .text).notNull()
                t.column("artist", .text).notNull()
                t.column("album", .text).notNull()
                t.column("genre", .text).notNull()
                t.column("duration", .double).notNull()
                t.column("position", .double).notNull().defaults(to: -1)
                t.column("playbackState", .integer).notNull()
                t.column("playbackRate", .double).notNull()
                t.column("os", .text).notNull()
                t.column("timezone", .integer).notNull()
                t.column("jsonVersion", .integer).notNull()
            }
            try migrateTableIfNeeded(db)
        }
    }

    private static func migrateTableIfNeeded(_ db: GRDB.Database) throws {
        let columns = Set(try db.columns(in: databaseTableName).map(\.name))
        if columns.contains("position") == false {
            try db.alter(table: databaseTableName) { t in
                t.add(column: "position", .double).notNull().defaults(to: -1)
            }
        }
    }
}
