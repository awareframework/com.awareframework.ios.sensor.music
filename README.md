# AWARE: Music

[![Swift Package Manager compatible](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)

This sensor module monitors the system music player using the MediaPlayer framework. It records playback state changes (playing, paused, stopped, etc.) and now-playing item changes (track changes), capturing metadata such as title, artist, album, genre, duration, and playback position.

## Requirements
iOS 14 or later

## Installation

1. Open Package Manager Windows
    * Open `Xcode` -> Select `Menu Bar` -> `File` -> `App Package Dependencies...`

2. Find the package using the manager
    * Select `Search Package URL` and type `https://github.com/awareframework/com.awareframework.ios.sensor.music.git`

3. Import the package into your target.

4. Add `NSAppleMusicUsageDescription` to your `Info.plist`.

## Public functions

### MusicSensor

+ `init(_ config: MusicSensor.Config)`: Initializes the sensor with the given configuration.
+ `start()`: Requests media library authorization and begins observing playback notifications.
+ `stop()`: Stops observing playback notifications.
+ `sync(force:)`: Syncs stored data to the configured host.
+ `set(label:)`: Sets a custom label applied to all subsequent data points.

### MusicSensor.Config

Class to hold the configuration of the sensor.

#### Fields

+ `sensorObserver: MusicObserver?`: Callback for live data updates.
+ `emitInitialState: Bool`: If `true`, immediately fires callbacks for the current playback state and now-playing item when the sensor starts. (default = `true`)
+ `duplicateEventSuppressionInterval: TimeInterval`: Minimum time interval (seconds) between identical events to suppress duplicates. (default = `1.0`)
+ `enabled: Bool`: Sensor is enabled or not. (default = `false`)
+ `debug: Bool`: Enable/disable logging. (default = `false`)
+ `label: String`: Label for the data. (default = "")
+ `deviceId: String`: Id of the device associated with the events. (default = "")
+ `dbEncryptionKey`: Encryption key for the database. (default = `nil`)
+ `dbType: Engine`: Which db engine to use for saving data. (default = `Engine.DatabaseType.NONE`)
+ `dbPath: String`: Path of the database. (default = "aware_music")
+ `dbHost: String`: Host for syncing the database. (default = `nil`)

## Broadcasts

### Fired Broadcasts

+ `MusicSensor.ACTION_AWARE_MUSIC_PLAYBACK_STATE_CHANGED`: fired when the playback state changes (playing, paused, stopped, etc.).
+ `MusicSensor.ACTION_AWARE_MUSIC_NOW_PLAYING_ITEM_CHANGED`: fired when the now-playing track changes.

### Received Broadcasts

+ `MusicSensor.ACTION_AWARE_MUSIC_START`: received broadcast to start the sensor.
+ `MusicSensor.ACTION_AWARE_MUSIC_STOP`: received broadcast to stop the sensor.
+ `MusicSensor.ACTION_AWARE_MUSIC_SYNC`: received broadcast to send sync attempt to the host.
+ `MusicSensor.ACTION_AWARE_MUSIC_SET_LABEL`: received broadcast to set the data label. Label is expected in the `MusicSensor.EXTRA_LABEL` field of the notification userInfo.

## Data Representations

### MusicData

Contains the playback event data.

| Field         | Type   | Description                                                                                         |
| ------------- | ------ | --------------------------------------------------------------------------------------------------- |
| title         | String | Song title                                                                                          |
| artist        | String | Artist name                                                                                         |
| album         | String | Album title                                                                                         |
| genre         | String | Genre                                                                                               |
| duration      | Double | Track duration in seconds                                                                           |
| position      | Double | Playback position at the event time in seconds (-1 if unavailable)                                 |
| playbackState | Int    | MPMusicPlaybackState raw value: 0=stopped, 1=playing, 2=paused, 3=interrupted, 4=seekFwd, 5=seekBwd |
| playbackRate  | Double | Current playback rate (0.0=paused, 1.0=normal speed)                                               |
| label         | String | Customizable label. Useful for data calibration or traceability                                     |
| deviceId      | String | AWARE device UUID                                                                                   |
| timestamp     | Int64  | Unixtime milliseconds since 1970                                                                    |
| timezone      | Int    | Timezone of the device                                                                              |
| os            | String | Operating system of the device (iOS)                                                                |
| jsonVersion   | Int    | JSON schema version                                                                                 |

## Example usage

```swift
import com_awareframework_ios_sensor_music
```

```swift
let sensor = MusicSensor(MusicSensor.Config().apply { config in
    config.sensorObserver = Observer()
    config.emitInitialState = true
    config.debug = true
})

sensor.start()

// Later...
sensor.stop()
```

```swift
class Observer: MusicObserver {
    func onPlaybackStateChanged(data: MusicData) {
        print("State:", data.playbackState, "Track:", data.title)
    }

    func onNowPlayingItemChanged(data: MusicData) {
        print("Now playing:", data.title, "-", data.artist)
    }
}
```

## Author
Yuuki Nishiyama (The University of Tokyo), nishiyama@csis.u-tokyo.ac.jp

## Related Links
* [Apple | MediaPlayer](https://developer.apple.com/documentation/mediaplayer)
* [Apple | MPMusicPlayerController](https://developer.apple.com/documentation/mediaplayer/mpmusicplayercontroller)

## License
Copyright (c) 2018 AWARE Mobile Context Instrumentation Middleware/Framework (http://www.awareframework.com)

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0 Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.