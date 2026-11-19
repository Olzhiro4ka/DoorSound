import Foundation

class AppState {
    var isEnabled = true {
        didSet {
            if !isEnabled {
                currentEngine?.stop()
                lastAngle = nil
                smoothedVelocity = 0
            }
        }
    }
    var volume: Float = 0.7
    var sensorUnavailable = false
    private let lidSensor = LidAngleSensor()
    private let currentEngine = RecordedDoorEngine()

    private var sensorTimer: DispatchSourceTimer?
    private var lastAngle: Double?
    private var lastAngleTime: TimeInterval = 0
    private var lastSampleTime: TimeInterval = 0
    private var lastChangeTime: TimeInterval = 0
    private var smoothedVelocity: Double = 0
    private var isHighFreq = false

    private let silenceDelay: TimeInterval = 0.16
    private let highFreqDuration: TimeInterval = 10.0

    init() {
        sensorUnavailable = !lidSensor.isAvailable
        startMonitoring()
    }

    private func startMonitoring() {
        setSensorRate(fast: false)
    }

    private func setSensorRate(fast: Bool) {
        sensorTimer?.cancel()
        sensorTimer = DispatchSource.makeTimerSource(queue: .main)
        let ms = fast ? 33 : 100  // 30fps vs 10fps
        sensorTimer?.schedule(deadline: .now(), repeating: .milliseconds(ms))
        sensorTimer?.setEventHandler { [weak self] in
            self?.pollSensor()
        }
        sensorTimer?.resume()
        isHighFreq = fast
        if fast {
            NSLog("[DoorSound] Sensor → 30fps")
        } else {
            NSLog("[DoorSound] Sensor → 10fps")
        }
    }

    private func switchToHighFreq() {
        guard !isHighFreq else { return }
        setSensorRate(fast: true)
    }

    private func switchToLowFreq() {
        guard isHighFreq else { return }
        setSensorRate(fast: false)
    }

    private func pollSensor() {
        guard isEnabled else { return }

        let angle = lidSensor.readAngle()
        guard angle >= 0 else {
            sensorUnavailable = true
            currentEngine?.stop()
            lastAngle = nil
            smoothedVelocity = 0
            return
        }

        sensorUnavailable = false
        let now = ProcessInfo.processInfo.systemUptime

        let sampleInterval = now - lastSampleTime
        lastSampleTime = now
        guard let previousAngle = lastAngle, sampleInterval < 0.4 else {
            currentEngine?.stop()
            smoothedVelocity = 0
            lastAngle = angle
            lastAngleTime = now
            return
        }

        let delta = angle - previousAngle
        if abs(delta) >= 0.02 {
            let velocity = delta / max(0.001, now - lastAngleTime)
            if smoothedVelocity * velocity <= 0 {
                smoothedVelocity = velocity
            } else {
                smoothedVelocity = smoothedVelocity * 0.55 + velocity * 0.45
            }
            lastAngle = angle
            lastAngleTime = now
            lastChangeTime = now
            switchToHighFreq()
            currentEngine?.play(velocity: smoothedVelocity, volume: volume)
        } else if now - lastChangeTime > silenceDelay {
            smoothedVelocity = 0
            currentEngine?.stop()
            if isHighFreq && now - lastChangeTime > highFreqDuration {
                switchToLowFreq()
            }
        }
    }
}
