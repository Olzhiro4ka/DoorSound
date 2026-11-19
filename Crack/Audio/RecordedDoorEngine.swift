import AVFoundation
import os

final class RecordedDoorEngine {
    private static let sampleRate = 44_100.0
    private let engine = AVAudioEngine()
    private let motion = OSAllocatedUnfairLock(initialState: Motion())

    private struct Motion {
        var generation = 0
        var moving = false
        var opening = true
        var rate = 1.0
        var gain: Float = 0
    }

    init?(bundle: Bundle = .main) {
        guard let opening = Self.load("door-opening", from: bundle),
              let closing = Self.load("door-closing", from: bundle),
              let format = AVAudioFormat(standardFormatWithSampleRate: Self.sampleRate, channels: 1) else {
            NSLog("[DoorSound] Could not load door recordings")
            return nil
        }

        let motion = self.motion
        var target = Motion()
        var generation = 0
        var clip = opening
        var position = Double(opening.count)
        var rate = 1.0
        var gain: Float = 0

        let source = AVAudioSourceNode(format: format) { _, _, frameCount, bufferList in
            if let update = motion.withLockIfAvailable({ $0 }) {
                target = update
            }

            let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
            guard let output = buffers.first?.mData?.assumingMemoryBound(to: Float.self) else {
                return noErr
            }

            for frame in 0..<Int(frameCount) {
                // Fade the outgoing take before starting the next movement.
                let switching = target.moving && target.generation != generation
                if switching && gain < 0.002 {
                    generation = target.generation
                    clip = target.opening ? opening : closing
                    position = 0
                    gain = 0
                    rate = target.rate
                }

                let fadingOut = target.generation != generation
                let desiredGain = target.moving && !fadingOut ? target.gain : 0
                gain += (desiredGain - gain) * (fadingOut ? 0.006 : 0.0013)
                rate += (target.rate - rate) * 0.00065

                let index = Int(position)
                if index < clip.count - 1 {
                    let fraction = Float(position - Double(index))
                    let sample = clip[index] + fraction * (clip[index + 1] - clip[index])
                    output[frame] = gain * sample
                    position += rate
                } else {
                    output[frame] = 0
                    gain = 0
                }
            }

            return noErr
        }

        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: format)
    }

    func play(velocity: Double, volume: Float) {
        let opening = velocity > 0
        let speed = abs(velocity)
        let speedGain = Float(min(1, 0.2 + 0.8 * sqrt(speed / 95)))
        motion.withLock { state in
            if !state.moving || state.opening != opening {
                state.generation += 1
            }
            state.opening = opening
            state.moving = true
            state.rate = min(1.35, 0.83 + speed / 190)
            state.gain = volume * speedGain
        }

        if volume > 0 && !engine.isRunning {
            do { try engine.start() } catch { NSLog("[DoorSound] Audio: %@", error.localizedDescription) }
        }
    }

    func stop() {
        motion.withLock { $0.moving = false }
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
