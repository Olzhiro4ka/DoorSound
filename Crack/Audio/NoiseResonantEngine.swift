import AVFoundation

// MARK: - Noise Preset Parameters

struct NoisePreset {
    let name: String
    let freqs: [Float]       // 3 resonator center frequencies
    let qs: [Float]          // 3 resonator Q values
    let freqShifts: [Float]  // how much each shifts with excitation
    let mix: [Float]         // 3 resonator mix levels
    let drive: Float
    let usePink: Bool        // true = pink noise, false = white

    static let all: [NoisePreset] = [
        NoisePreset(name: "Wind", freqs: [320, 680, 1400], qs: [40, 30, 20],
                    freqShifts: [200, 150, 100], mix: [0.5, 0.35, 0.15], drive: 3.0, usePink: true),
        NoisePreset(name: "Arctic Wind", freqs: [1000, 3000, 7000], qs: [25, 30, 20],
                    freqShifts: [300, 500, 800], mix: [0.3, 0.4, 0.3], drive: 3.5, usePink: true),
    ]
}

// MARK: - Parameterized Noise+Filter Engine

class NoiseResonantEngine: CreakAudioEngine {
    private var engine: AVAudioEngine!
    private var srcNode: AVAudioSourceNode!
    private var isPlaying = false
    var volume: Float = 0.7
    private let state = SynthState()

    init(preset: NoisePreset = NoisePreset.all[0]) {
        let sr: Float = 44100
        let synthState = state
        let p = preset

        var bp_y: [(Float, Float)] = Array(repeating: (0, 0), count: 3)
        var pinkState: [Float] = [0, 0, 0, 0, 0, 0, 0]

        engine = AVAudioEngine()
        srcNode = AVAudioSourceNode { (_, _, frameCount, bufferList) -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(bufferList)
            let frames = Int(frameCount)

            for frame in 0..<frames {
                synthState.excitation += (synthState.targetExcitation - synthState.excitation) * 0.001
                synthState.currentVolume += (synthState.targetVolume - synthState.currentVolume) * 0.002
                let exc = synthState.excitation

                let white = Float.random(in: -1...1)
                let noiseSource: Float
                if p.usePink {
                    pinkState[0] = 0.99886 * pinkState[0] + white * 0.0555179
                    pinkState[1] = 0.99332 * pinkState[1] + white * 0.0750759
                    pinkState[2] = 0.96900 * pinkState[2] + white * 0.1538520
                    pinkState[3] = 0.86650 * pinkState[3] + white * 0.3104856
                    pinkState[4] = 0.55000 * pinkState[4] + white * 0.5329522
                    pinkState[5] = -0.7616 * pinkState[5] - white * 0.0168980
                    noiseSource = (pinkState[0] + pinkState[1] + pinkState[2]
                        + pinkState[3] + pinkState[4] + pinkState[5]
                        + pinkState[6] + white * 0.5362) * 0.11
                    pinkState[6] = white * 0.115926
                } else {
                    noiseSource = white
                }

                let noise = noiseSource * exc * 2.0

                func bpf(_ input: Float, _ freq: Float, _ q: Float, _ idx: Int) -> Float {
                    let w0 = 2.0 * Float.pi * freq / sr
                    let alpha = sin(w0) / (2.0 * q)
                    let cosw0 = cos(w0)
                    let b0 = alpha, a0 = 1.0 + alpha
                    let a1 = -2.0 * cosw0, a2 = 1.0 - alpha
                    let out = (b0/a0) * input - (a1/a0) * bp_y[idx].0 - (a2/a0) * bp_y[idx].1
                    bp_y[idx].1 = bp_y[idx].0; bp_y[idx].0 = out
                    return out
                }

                var mixed: Float = 0
                for i in 0..<3 {
                    let f = p.freqs[i] + exc * p.freqShifts[i]
                    mixed += bpf(noise, f, p.qs[i], i) * p.mix[i]
                }

                let output = tanh(mixed * p.drive) * synthState.currentVolume * 0.5

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
