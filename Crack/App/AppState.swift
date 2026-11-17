import Foundation

class AppState {
    var isEnabled = true {
        didSet {
            if !isEnabled {
                currentEngine.stop()
                lastAngle = nil
            }
        }
    }
    var volume: Float = 0.7
    var selectedSound: String = "Knuckle Crack" {
        didSet {
            NSLog("[DoorSound] Switching sound to: %@", selectedSound)
            currentEngine.stop()
            if let engine = engineMap[selectedSound] {
                currentEngine = engine
            }
        }
    }
    var sensorUnavailable = false
    var availableSounds: [String] = []

    static var synthNames: [String] {
        let crackNames = CrackPreset.all.map { $0.name }
        let fmNames = FMPreset.all.map { $0.name }
        let noiseNames = NoisePreset.all.map { $0.name }
        return crackNames + fmNames + noiseNames
    }

    func isSynthEngine(_ name: String) -> Bool {
        return engineMap[name] != nil
    }

    let lidSensor = LidAngleSensor()
    var engineMap: [String: CreakAudioEngine] = [:]
    var currentEngine: CreakAudioEngine!

    private var sensorTimer: DispatchSourceTimer?
    private var lastAngle: Double?
    private var lastAngleTime: TimeInterval = 0
    private var lastChangeTime: TimeInterval = 0
    private var smoothedVelocity: Double = 0
    private var logCounter = 0
    private var isHighFreq = false

    private let silenceDelay: TimeInterval = 0.15
    private let highFreqDuration: TimeInterval = 10.0

    init() {
        // Build engine map
        for p in CrackPreset.all {
            engineMap[p.name] = SynthCrackEngine(preset: p)
        }
        for p in FMPreset.all {
            engineMap[p.name] = FMSynthEngine(preset: p)
        }
        for p in NoisePreset.all {
            engineMap[p.name] = NoiseResonantEngine(preset: p)
        }

        let defaultName = "Door"
        currentEngine = engineMap[defaultName]!
        selectedSound = defaultName
        sensorUnavailable = !lidSensor.isAvailable
        availableSounds = AppState.synthNames
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
            currentEngine.stop()
            lastAngle = nil
            smoothedVelocity = 0
            return
        }

        let now = ProcessInfo.processInfo.systemUptime

        defer {
            lastAngle = angle
            lastAngleTime = now
        }

        guard let prevAngle = lastAngle else { return }

        let dt = now - lastAngleTime
        guard dt > 0 else { return }

        let delta = abs(angle - prevAngle)

        if delta > 0.02 {
            let instantVel = delta / dt
            smoothedVelocity = smoothedVelocity * 0.6 + instantVel * 0.4
            lastChangeTime = now

            // Switch to high frequency polling on movement
            switchToHighFreq()

            let rate = mapVelocityToRate(smoothedVelocity)
            if logCounter % 30 == 0 {
                NSLog("[DoorSound] PLAY delta=%.4f° vel=%.3f°/s smooth=%.3f rate=%.2f", delta, instantVel, smoothedVelocity, rate)
            }
            logCounter += 1
            currentEngine.play(rate: rate, volume: volume)
        } else if now - lastChangeTime > silenceDelay {
            smoothedVelocity = 0
            currentEngine.stop()
            // Drop back to low frequency after no movement for highFreqDuration
            if isHighFreq && now - lastChangeTime > highFreqDuration {
                switchToLowFreq()
            }
        }
    }

    private func mapVelocityToRate(_ velocity: Double) -> Float {
        return Float(max(0.1, velocity * 0.4))
    }
}
