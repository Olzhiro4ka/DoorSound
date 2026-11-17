import AVFoundation

// MARK: - Crack Preset Parameters

struct CrackPreset {
    let name: String
    let crackRateMultiplier: Float   // how often cracks fire
    let decayRate: Float             // 0.9 = very short, 0.95 = longer
    let gateThreshold: Float
    let freqs: [Float]               // 5 resonator frequencies
    let qs: [Float]                  // 5 resonator Q values
    let mix: [Float]                 // 5 resonator mix levels
    let freqShift: Float             // how much freq shifts with excitation
    let drive: Float                 // output saturation
    let clickMix: Float              // raw click vs filtered ratio

    // Door with 2x accelerated frequencies
    static let all: [CrackPreset] = [
        CrackPreset(name: "Door",
                    crackRateMultiplier: 0.2, decayRate: 0.977, gateThreshold: 0.03,
                    freqs: [140, 320, 800, 2080, 5200], qs: [3, 4, 6, 5, 4],
                    mix: [0.3, 0.3, 0.25, 0.1, 0.05], freqShift: 0.3, drive: 7.0, clickMix: 0.5),
    ]
}

// MARK: - Parameterized Crack Engine

class SynthCrackEngine: CreakAudioEngine {
    private var engine: AVAudioEngine!
    private var srcNode: AVAudioSourceNode!
    private var isPlaying = false
    var volume: Float = 0.7
    private let state = SynthState()

    init(preset: CrackPreset = CrackPreset.all[0]) {
        let sr: Float = 44100
        let synthState = state
        let p = preset

        var burstEnvelope: Float = 0
        var burstPhase: Float = 0

        // 5 resonator states
        var ry: [(Float, Float)] = Array(repeating: (0, 0), count: 5)

        engine = AVAudioEngine()
        srcNode = AVAudioSourceNode { (_, _, frameCount, bufferList) -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(bufferList)
            let frames = Int(frameCount)

            for frame in 0..<frames {
                synthState.excitation += (synthState.targetExcitation - synthState.excitation) * 0.001
                synthState.currentVolume += (synthState.targetVolume - synthState.currentVolume) * 0.002
                let exc = synthState.excitation

                burstPhase += exc * 0.006 * p.crackRateMultiplier + 0.0001
                if burstPhase > 1.0 + Float.random(in: 0...1.0) {
                    burstPhase = 0
                    burstEnvelope = 1.0
                }

                burstEnvelope *= p.decayRate
                if burstEnvelope < p.gateThreshold { burstEnvelope = 0 }

                let excSignal: Float
                if burstEnvelope > 0 {
                    let click = burstEnvelope * burstEnvelope * burstEnvelope
                    excSignal = click * exc * 3.0
                } else {
                    excSignal = 0
                }

                func bp(_ input: Float, _ freq: Float, _ q: Float, _ idx: Int) -> Float {
                    let w0 = 2.0 * Float.pi * freq / sr
                    let alpha = sin(w0) / (2.0 * q)
                    let cosw0 = cos(w0)
                    let b0 = alpha, a0 = 1.0 + alpha
                    let a1 = -2.0 * cosw0, a2 = 1.0 - alpha
                    let out = (b0/a0) * input - (a1/a0) * ry[idx].0 - (a2/a0) * ry[idx].1
                    ry[idx].1 = ry[idx].0; ry[idx].0 = out
                    return out
                }

                var mixed: Float = 0
                for i in 0..<5 {
                    let f = p.freqs[i] + exc * p.freqs[i] * 0.3 * p.freqShift
                    mixed += bp(excSignal, f, p.qs[i], i) * p.mix[i]
                }

                let withClick = mixed + excSignal * p.clickMix
                let output = tanh(withClick * p.drive) * synthState.currentVolume * 0.6

                for buffer in abl { buffer.mData!.assumingMemoryBound(to: Float.self)[frame] = output }
            }
            return noErr
        }

        engine.attach(srcNode)
        engine.connect(srcNode, to: engine.mainMixerNode,
                       format: AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!)
    }

    func play(rate: Float, volume: Float) {
        self.volume = volume; state.targetExcitation = min(rate, 4.0); state.targetVolume = volume
        if !engine.isRunning { do { try engine.start() } catch { return } }; isPlaying = true
    }
    func tick() {}
    func fadeOut() {
        state.targetExcitation = 0; state.targetVolume = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.isPlaying = false }
    }
    func stop() { state.targetExcitation = 0; state.targetVolume = 0; isPlaying = false }
}

