import AVFoundation

// MARK: - Protocol for all audio engines

protocol CreakAudioEngine: AnyObject {
    var volume: Float { get set }
    func play(rate: Float, volume: Float)
    func fadeOut()
    func stop()
    func tick()
}

// MARK: - Shared synth state

class SynthState {
    var targetExcitation: Float = 0
    var excitation: Float = 0
    var targetVolume: Float = 0
    var currentVolume: Float = 0
}

