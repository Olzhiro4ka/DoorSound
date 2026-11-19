import AVFoundation
import os

final class RecordedDoorEngine {
    private static let sampleRate = 44_100.0
    private let engine = AVAudioEngine()
    private let motion = OSAllocatedUnfairLock(initialState: Motion())

    private struct Motion {
        var progress = 0.0
        var opening = true
        var gain: Float = 0
    }

    private struct Grain {
        var start = 0
        var opening = true
    }

    init?(bundle: Bundle = .main) {
        guard let opening = Self.load("door-opening", from: bundle),
              let closing = Self.load("door-closing", from: bundle),
              let format = AVAudioFormat(standardFormatWithSampleRate: Self.sampleRate, channels: 1) else {
            NSLog("[DoorSound] Could not load door recordings")
            return nil
        }

        // Two overlapping excerpts follow the lid position at the recording's
        // original pitch. A change in direction fades into the other recording.
        let hop = 1_536
        let length = hop * 2
        let window = (0..<length).map { frame in
            Float(0.5 - 0.5 * cos(2 * .pi * Double(frame) / Double(length)))
        }
        let motion = self.motion
        var target = Motion()
        var previous = Grain()
        var current = Grain()
        var phase = 0
        var gain: Float = 0

        let source = AVAudioSourceNode { _, _, frameCount, bufferList in
            if let update = motion.withLockIfAvailable({ $0 }) {
                target = update
            }
            let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
            guard let output = buffers.first?.mData?.assumingMemoryBound(to: Float.self) else {
                return noErr
            }
            for frame in 0..<Int(frameCount) {
                if phase == 0 {
                    previous = current
                    let count = target.opening ? opening.count : closing.count
                    current = Grain(start: Int(target.progress * Double(count - length)), opening: target.opening)
                }
                gain += (target.gain - gain) * (target.gain > gain ? 0.0013 : 0.00065)
                if gain < 0.00001 && target.gain == 0 { gain = 0 }
                let old = previous.opening ? opening : closing
                let new = current.opening ? opening : closing
                output[frame] = gain * (
                    old[previous.start + hop + phase] * window[hop + phase] +
                    new[current.start + phase] * window[phase]
                )
                phase += 1
                if phase == hop { phase = 0 }
            }
            return noErr
        }
        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: format)
    }

    func play(angle: Double, velocity: Double, volume: Float) {
        let opening = velocity > 0
        let travel = min(1, max(0, angle / 135))
        let speedGain = Float(min(1, 0.35 + sqrt(abs(velocity) / 100) * 0.65))
        let update = Motion(progress: opening ? travel : 1 - travel, opening: opening, gain: volume * speedGain)
        motion.withLock { $0 = update }
        if update.gain > 0 && !engine.isRunning {
            do { try engine.start() } catch { NSLog("[DoorSound] Audio: %@", error.localizedDescription) }
        }
    }

    func stop() {
        motion.withLock { $0.gain = 0 }
    }

    private static func load(_ name: String, from bundle: Bundle) -> [Float]? {
        guard let url = bundle.url(forResource: name, withExtension: "wav"),
              let file = try? AVAudioFile(forReading: url),
              file.processingFormat.sampleRate == sampleRate,
              file.processingFormat.channelCount == 1,
              file.length >= 3_072,
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else {
            return nil
        }
        do { try file.read(into: buffer) } catch { return nil }
        guard let channel = buffer.floatChannelData?[0], buffer.frameLength >= 3_072 else { return nil }
        return Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
    }
}
