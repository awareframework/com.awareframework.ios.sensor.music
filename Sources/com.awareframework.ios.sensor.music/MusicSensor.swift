import Foundation
import MediaPlayer
import com_awareframework_ios_core

extension Notification.Name {
    public static let actionAwareMusicStart = Notification.Name(MusicSensor.ACTION_AWARE_MUSIC_START)
    public static let actionAwareMusicStop = Notification.Name(MusicSensor.ACTION_AWARE_MUSIC_STOP)
    public static let actionAwareMusicSync = Notification.Name(MusicSensor.ACTION_AWARE_MUSIC_SYNC)
    public static let actionAwareMusicSyncCompletion = Notification.Name(MusicSensor.ACTION_AWARE_MUSIC_SYNC_COMPLETION)
    public static let actionAwareMusicSetLabel = Notification.Name(MusicSensor.ACTION_AWARE_MUSIC_SET_LABEL)
    public static let actionAwareMusicPlaybackStateChanged = Notification.Name(MusicSensor.ACTION_AWARE_MUSIC_PLAYBACK_STATE_CHANGED)
    public static let actionAwareMusicNowPlayingItemChanged = Notification.Name(MusicSensor.ACTION_AWARE_MUSIC_NOW_PLAYING_ITEM_CHANGED)
}

public protocol MusicObserver {
    func onPlaybackStateChanged(data: MusicData)
    func onNowPlayingItemChanged(data: MusicData)
}

private enum MusicEventType {
    case playbackStateChanged
    case nowPlayingItemChanged
}

public class MusicSensor: AwareSensor {

    public static let TAG = "AWARE::Music"

    public static let ACTION_AWARE_MUSIC_START = "com.awareframework.ios.sensor.music.SENSOR_START"
    public static let ACTION_AWARE_MUSIC_STOP = "com.awareframework.ios.sensor.music.SENSOR_STOP"
    public static let ACTION_AWARE_MUSIC_SYNC = "com.awareframework.ios.sensor.music.SENSOR_SYNC"
    public static let ACTION_AWARE_MUSIC_SYNC_COMPLETION = "com.awareframework.ios.sensor.music.SENSOR_SYNC_COMPLETION"
    public static let ACTION_AWARE_MUSIC_SET_LABEL = "com.awareframework.ios.sensor.music.SET_LABEL"

    /// Fired event: playback state changed (playing/paused/stopped/etc.)
    public static let ACTION_AWARE_MUSIC_PLAYBACK_STATE_CHANGED = "com.awareframework.ios.sensor.music.PLAYBACK_STATE_CHANGED"

    /// Fired event: now playing item changed (track changed)
    public static let ACTION_AWARE_MUSIC_NOW_PLAYING_ITEM_CHANGED = "com.awareframework.ios.sensor.music.NOW_PLAYING_ITEM_CHANGED"

    public static let EXTRA_LABEL = "label"
    public static let EXTRA_DATA = "data"
    public static let EXTRA_STATUS = "status"
    public static let EXTRA_ERROR = "error"
    public static let EXTRA_OBJECT_TYPE = "objectType"
    public static let EXTRA_TABLE_NAME = "tableName"
    public static let EXTRA_AUTHORIZATION_STATUS = "authorizationStatus"

    public var CONFIG = Config()

    private var playbackStateObserver: NSObjectProtocol?
    private var nowPlayingItemObserver: NSObjectProtocol?
    private var isObservingPlaybackNotifications = false
    private var lastDispatchedSnapshotKey: String?
    private var lastDispatchedTimestamp: TimeInterval = 0

    public class Config: SensorConfig {
        public var sensorObserver: MusicObserver?
        public var emitInitialState = true
        public var duplicateEventSuppressionInterval: TimeInterval = 1.0

        public override init() {
            super.init()
            dbPath = "aware_music"
        }

        public func apply(closure: (_ config: MusicSensor.Config) -> Void) -> Self {
            closure(self)
            return self
        }
    }

    public override convenience init() {
        self.init(MusicSensor.Config())
    }

    public init(_ config: MusicSensor.Config) {
        super.init()
        CONFIG = config
        initializeDbEngine(config: config)
        super.syncConfig = DbSyncConfig().apply { syncConfig in
            syncConfig.serverType = config.serverType
            syncConfig.debug = config.debug
            syncConfig.batchSize = 1000
            syncConfig.dispatchQueue = DispatchQueue(label: "com.awareframework.ios.sensor.music.sync.queue")
            syncConfig.completionHandler = { [weak self] status, error in
                guard let self else { return }
                var userInfo: [String: Any] = [
                    MusicSensor.EXTRA_STATUS: status,
                    MusicSensor.EXTRA_TABLE_NAME: MusicData.TABLE_NAME,
                    MusicSensor.EXTRA_OBJECT_TYPE: MusicData.self,
                ]
                if let error = error {
                    userInfo[MusicSensor.EXTRA_ERROR] = error
                }
                self.notificationCenter.post(name: .actionAwareMusicSyncCompletion, object: self, userInfo: userInfo)
            }
        }
        initializeTables()
    }

    deinit {
        removePlaybackNotificationObservers()
    }

    public override func start() {
        requestMediaLibraryAuthorizationIfNeeded { [weak self] authorized, status in
            guard let self else { return }
            guard authorized else {
                self.postAuthorizationDenied(status: status)
                return
            }
            self.startObservingPlaybackNotifications()
        }
    }

    public override func stop() {
        removePlaybackNotificationObservers()
        notificationCenter.post(name: .actionAwareMusicStop, object: self)
    }

    public override func sync(force: Bool = false) {
        guard let syncConfig = super.syncConfig else { return }
        notificationCenter.post(name: .actionAwareMusicSync, object: self)
        dbEngine?.startSync(syncConfig)
    }

    public override func set(label: String) {
        CONFIG.label = label
        notificationCenter.post(
            name: .actionAwareMusicSetLabel, object: self,
            userInfo: [MusicSensor.EXTRA_LABEL: label])
    }

    private func handlePlaybackStateChange() {
        let player = MPMusicPlayerController.systemMusicPlayer
        let data = buildMusicData(from: player)
        dispatchMusicEvent(.playbackStateChanged, data: data)
    }

    private func handleNowPlayingItemChange() {
        let player = MPMusicPlayerController.systemMusicPlayer
        guard player.nowPlayingItem != nil else { return }

        let data = buildMusicData(from: player)
        dispatchMusicEvent(.nowPlayingItemChanged, data: data)
    }

    private func requestMediaLibraryAuthorizationIfNeeded(
        completion: @escaping (_ authorized: Bool, _ status: MPMediaLibraryAuthorizationStatus) -> Void
    ) {
        let status = MPMediaLibrary.authorizationStatus()
        switch status {
        case .authorized:
            DispatchQueue.main.async {
                completion(true, status)
            }
        case .notDetermined:
            MPMediaLibrary.requestAuthorization { newStatus in
                DispatchQueue.main.async {
                    completion(newStatus == .authorized, newStatus)
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                completion(false, status)
            }
        @unknown default:
            DispatchQueue.main.async {
                completion(false, status)
            }
        }
    }

    private func startObservingPlaybackNotifications() {
        guard !isObservingPlaybackNotifications else { return }

        let player = MPMusicPlayerController.systemMusicPlayer
        player.beginGeneratingPlaybackNotifications()

        playbackStateObserver = NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handlePlaybackStateChange()
        }

        nowPlayingItemObserver = NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleNowPlayingItemChange()
        }

        isObservingPlaybackNotifications = true
        notificationCenter.post(name: .actionAwareMusicStart, object: self)

        guard CONFIG.emitInitialState else { return }
        handlePlaybackStateChange()
        handleNowPlayingItemChange()
    }

    private func removePlaybackNotificationObservers() {
        if let observer = playbackStateObserver {
            NotificationCenter.default.removeObserver(observer)
            playbackStateObserver = nil
        }
        if let observer = nowPlayingItemObserver {
            NotificationCenter.default.removeObserver(observer)
            nowPlayingItemObserver = nil
        }
        if isObservingPlaybackNotifications {
            MPMusicPlayerController.systemMusicPlayer.endGeneratingPlaybackNotifications()
            isObservingPlaybackNotifications = false
        }
    }

    private func postAuthorizationDenied(status: MPMediaLibraryAuthorizationStatus) {
        if CONFIG.debug {
            print(MusicSensor.TAG, "media library authorization unavailable:", status.rawValue)
        }
        notificationCenter.post(
            name: .actionAwareMusicStart,
            object: self,
            userInfo: [
                MusicSensor.EXTRA_AUTHORIZATION_STATUS: status.rawValue,
                MusicSensor.EXTRA_ERROR: "Media library authorization is required to observe music events.",
            ])
    }

    private func buildMusicData(from player: MPMusicPlayerController) -> MusicData {
        var data = MusicData()
        data.label = CONFIG.label
        data.playbackState = player.playbackState.rawValue
        data.playbackRate = Double(player.currentPlaybackRate)
        data.position = player.currentPlaybackTime.isFinite ? player.currentPlaybackTime : -1

        if let item = player.nowPlayingItem {
            data.title = item.title ?? ""
            data.artist = item.artist ?? ""
            data.album = item.albumTitle ?? ""
            data.genre = item.genre ?? ""
            data.duration = item.playbackDuration
        }

        return data
    }

    private func dispatchMusicEvent(_ eventType: MusicEventType, data: MusicData) {
        guard shouldDispatch(data) else {
            if CONFIG.debug {
                print(MusicSensor.TAG, "duplicate event suppressed:", data.title, data.playbackState, data.position)
            }
            return
        }

        saveModels([data])

        switch eventType {
        case .playbackStateChanged:
            if CONFIG.debug {
                print(MusicSensor.TAG, "playback state changed:", data.playbackState, "position:", data.position)
            }
            CONFIG.sensorObserver?.onPlaybackStateChanged(data: data)
            notificationCenter.post(
                name: .actionAwareMusicPlaybackStateChanged,
                object: self,
                userInfo: [MusicSensor.EXTRA_DATA: data.toDictionary()])
        case .nowPlayingItemChanged:
            if CONFIG.debug {
                print(MusicSensor.TAG, "now playing changed:", data.title, "-", data.artist, "position:", data.position)
            }
            CONFIG.sensorObserver?.onNowPlayingItemChanged(data: data)
            notificationCenter.post(
                name: .actionAwareMusicNowPlayingItemChanged,
                object: self,
                userInfo: [MusicSensor.EXTRA_DATA: data.toDictionary()])
        }
    }

    private func shouldDispatch(_ data: MusicData) -> Bool {
        let now = Date().timeIntervalSince1970
        let snapshotKey = deduplicationKey(for: data)
        defer {
            lastDispatchedSnapshotKey = snapshotKey
            lastDispatchedTimestamp = now
        }

        guard let lastDispatchedSnapshotKey else { return true }
        let elapsed = now - lastDispatchedTimestamp
        return lastDispatchedSnapshotKey != snapshotKey || elapsed > CONFIG.duplicateEventSuppressionInterval
    }

    private func deduplicationKey(for data: MusicData) -> String {
        let positionBucket = data.position >= 0 ? Int(data.position.rounded()) : -1
        return [
            data.title,
            data.artist,
            data.album,
            "\(data.playbackState)",
            "\(positionBucket)",
        ].joined(separator: "|")
    }

    private func initializeTables() {
        guard let queue = (dbEngine as? SQLiteEngine)?.getSQLiteInstance() else { return }
        do {
            try MusicData.createTable(queue: queue)
        } catch {
            if CONFIG.debug { print(error) }
        }
    }

    private func saveModels<T: BaseDbModelSQLite>(_ models: [T]) {
        guard let engine = dbEngine as? SQLiteEngine else { return }
        engine.save(models)
    }
}
