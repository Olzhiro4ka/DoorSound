import AVFoundation

// MARK: - FM Preset Parameters

struct FMPreset {
    let name: String
    let carrierBase: Float
    let carrierRange: Float
    let modBase: Float
    let modRange: Float
    let modIndexBase: Float
    let modIndexRange: Float
    let noiseAmount: Float
    let drive: Float

    static let all: [FMPreset] = [
        FMPreset(name: "Cat", carrierBase: 180, carrierRange: 120, modBase: 230, modRange: 80,
                 modIndexBase: 2.0, modIndexRange: 6.0, noiseAmount: 0.3, drive: 1.5),
        FMPreset(name: "Alien Whisper", carrierBase: 80, carrierRange: 40, modBase: 90, modRange: 30,
                 modIndexBase: 1.0, modIndexRange: 3.0, noiseAmount: 0.5, drive: 1.0),
        FMPreset(name: "Whale Song", carrierBase: 40, carrierRange: 20, modBase: 45, modRange: 15,
                 modIndexBase: 1.5, modIndexRange: 4.0, noiseAmount: 0.4, drive: 1.2),
        FMPreset(name: "Warble", carrierBase: 350, carrierRange: 150, modBase: 6, modRange: 4,
                 modIndexBase: 150, modIndexRange: 300, noiseAmount: 0.1, drive: 1.2),
    ]
}

// MARK: - Parameterized FM Engine

class FMSynthEngine: CreakAudioEngine {
    private var engine: AVAudioEngine!
    private var srcNode: AVAudioSourceNode!
    private var isPlaying = false
    var volume: Float = 0.7
    private let state = SynthState()

    init(preset: FMPreset = FMPreset.all[0]) {
        let sr: Float = 44100
        let synthState = state
        let p = preset

        var carrierPhase: Float = 0
        var modPhase: Float = 0
        var nf_y1: Float = 0

        engine = AVAudioEngine()
        srcNode = AVAudioSourceNode { (_, _, frameCount, bufferList) -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(bufferList)
            let frames = Int(frameCount)

            for frame in 0..<frames {
                synthState.excitation += (synthState.targetExcitation - synthState.excitation) * 0.0005
                synthState.currentVolume += (synthState.targetVolume - synthState.currentVolume) * 0.002
                let exc = synthState.excitation

                let cFreq = p.carrierBase + exc * p.carrierRange
                let mFreq = p.modBase + exc * p.modRange
                let mIdx = p.modIndexBase + exc * p.modIndexRange

                modPhase += mFreq / sr
                if modPhase >= 1.0 { modPhase -= 1.0 }
                let modSig = sin(modPhase * 2.0 * Float.pi)

                carrierPhase += (cFreq + modSig * mIdx * mFreq) / sr
                if carrierPhase >= 1.0 { carrierPhase -= 1.0 }
                let carrier = sin(carrierPhase * 2.0 * Float.pi)

                let noise = Float.random(in: -1...1)
                nf_y1 = nf_y1 * 0.95 + noise * 0.05
                let fNoise = nf_y1 * exc * p.noiseAmount

                let amp = exc * 0.4
                let output = tanh((carrier * amp + fNoise) * synthState.currentVolume * p.drive) * 0.5

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

