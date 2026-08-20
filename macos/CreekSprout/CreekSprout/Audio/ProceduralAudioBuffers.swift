import AVFoundation
import Foundation

/// Original PCM generators. No files, no sampled melodies.
enum ProceduralAudioBuffers {
    static let sampleRate: Double = 44_100

    static func farmLoop() -> AVAudioPCMBuffer {
        makeLoop(seconds: 2.4) { t, n in
            let wind = filteredNoise(n: n, seed: 11, tone: 0.12) * (0.35 + 0.12 * sin(t * 0.7))
            let grass = rustle(n: n, seed: 29, rate: 14) * 0.18
            return (wind + grass) * 0.22
        }
    }

    static func creekLoop() -> AVAudioPCMBuffer {
        makeLoop(seconds: 2.6) { t, n in
            let water = filteredNoise(n: n, seed: 41, tone: 0.28) * (0.42 + 0.08 * sin(t * 1.3))
            let drip = sin(2 * .pi * 680 * t) * exp(-3.5 * (t.truncatingRemainder(dividingBy: 0.85))) * 0.04
            let bird = chirp(t: t, period: 1.9, base: 1680, seed: 7) * 0.07
            return (water + drip + bird) * 0.20
        }
    }

    static func rainLoop() -> AVAudioPCMBuffer {
        makeLoop(seconds: 2.0) { _, n in
            let drops = filteredNoise(n: n, seed: 73, tone: 0.62) * 0.55
            let body = filteredNoise(n: n, seed: 91, tone: 0.22) * 0.18
            return (drops + body) * 0.20
        }
    }

    static func bgmLoop() -> AVAudioPCMBuffer {
        // Original 7-beat woodblock + plucked ostinato. Not a known tune.
        let beats: [(Double, Double)] = [
            (0.00, 174.0),
            (0.50, 220.0),
            (1.00, 196.0),
            (1.50, 261.0),
            (2.10, 233.0),
            (2.70, 196.0),
            (3.30, 146.0),
        ]
        let length = 4.0
        return makeLoop(seconds: length) { t, n in
            var sample = filteredNoise(n: n, seed: 3, tone: 0.08) * 0.02
            for (start, freq) in beats {
                let local = t - start
                if local >= 0, local < 0.46 {
                    sample += plucked(freq: freq, t: local) * 0.22
                    sample += woodTick(t: local) * (start == 0 || start == 1.5 ? 0.18 : 0.10)
                }
            }
            return sample * 0.55
        }
    }

    static func cue(_ cue: UISoundCue) -> AVAudioPCMBuffer {
        switch cue {
        case .harvest:
            return oneShot(seconds: 0.18) { t, n in
                woodTick(t: t) * 0.45 + plucked(freq: 196, t: t) * 0.20
                    + filteredNoise(n: n, seed: 5, tone: 0.4) * 0.08 * exp(-t * 14)
            }
        case .deposit:
            return oneShot(seconds: 0.22) { t, _ in
                plucked(freq: 392, t: t) * 0.28 + plucked(freq: 523, t: t) * 0.16
            }
        case .settle:
            return oneShot(seconds: 0.42) { t, _ in
                plucked(freq: 261, t: t) * 0.22
                    + plucked(freq: 329, t: max(0, t - 0.08)) * 0.18
                    + plucked(freq: 392, t: max(0, t - 0.16)) * 0.14
            }
        case .talk:
            return oneShot(seconds: 0.12) { t, n in
                woodTick(t: t) * 0.32 + filteredNoise(n: n, seed: 17, tone: 0.5) * 0.05 * exp(-t * 18)
            }
        case .craft:
            return oneShot(seconds: 0.20) { t, _ in
                woodTick(t: t) * 0.28 + woodTick(t: max(0, t - 0.07)) * 0.22
            }
        }
    }

    // MARK: - Oscillators

    private static func plucked(freq: Double, t: Double) -> Double {
        guard t >= 0 else { return 0 }
        let burst = sin(2 * .pi * freq * t) * exp(-t * 6.5)
        let partial = sin(2 * .pi * freq * 2.01 * t) * exp(-t * 9) * 0.25
        return burst + partial
    }

    private static func woodTick(t: Double) -> Double {
        guard t >= 0 else { return 0 }
        return sin(2 * .pi * 110 * t) * exp(-t * 28) + sin(2 * .pi * 340 * t) * exp(-t * 40) * 0.35
    }

    private static func chirp(t: Double, period: Double, base: Double, seed: Int) -> Double {
        let phase = t.truncatingRemainder(dividingBy: period)
        guard phase < 0.16 else { return 0 }
        let freq = base + Double(seed * 13) + 420 * phase
        return sin(2 * .pi * freq * phase) * exp(-phase * 14)
    }

    private static func rustle(n: Int, seed: Int, rate: Int) -> Double {
        if n % max(rate * 80, 1) < 12 {
            return hashedNoise(n: n, seed: seed) * 0.8
        }
        return 0
    }

    private static func filteredNoise(n: Int, seed: Int, tone: Double) -> Double {
        let raw = hashedNoise(n: n, seed: seed)
        let prev = hashedNoise(n: n &- 1, seed: seed)
        return raw * tone + prev * (1 - tone)
    }

    private static func hashedNoise(n: Int, seed: Int) -> Double {
        var x = UInt32(truncatingIfNeeded: n &* 747_796_405 &+ seed &* 2_899_333)
        x = (x ^ (x >> 16)) &* 0x7FEB_352D
        x = (x ^ (x >> 15)) &* 0x846C_A68B
        x = x ^ (x >> 16)
        return Double(Int32(bitPattern: x)) / Double(Int32.max)
    }

    private static func makeLoop(seconds: Double, sample: (Double, Int) -> Double) -> AVAudioPCMBuffer {
        buffer(seconds: seconds, fade: 0.04, sample: sample)
    }

    private static func oneShot(seconds: Double, sample: (Double, Int) -> Double) -> AVAudioPCMBuffer {
        buffer(seconds: seconds, fade: 0.008, sample: sample)
    }

    private static func buffer(
        seconds: Double,
        fade: Double,
        sample: (Double, Int) -> Double
    ) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let frames = AVAudioFrameCount(seconds * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let fadeFrames = max(1, Int(fade * sampleRate))
        guard let channel = buffer.floatChannelData?[0] else { return buffer }
        for i in 0..<Int(frames) {
            let t = Double(i) / sampleRate
            var value = sample(t, i)
            if i < fadeFrames {
                value *= Double(i) / Double(fadeFrames)
            }
            let remaining = Int(frames) - i
            if remaining < fadeFrames {
                value *= Double(remaining) / Double(fadeFrames)
            }
            channel[i] = Float(max(-1, min(1, value)))
        }
        return buffer
    }
}
