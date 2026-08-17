// Converts a simulator screen recording into an App Store preview.
//
// Apple requires EXACTLY 886x1920 for 6.9" iPhone previews, 30fps, H.264,
// 15-30s. The simulator records 1320x2868, which is a slightly different aspect
// ratio (0.4603 vs 0.4615) — so this scales to FILL and centre-crops the couple
// of pixels of overshoot rather than squashing the image, which would show as
// subtly wrong proportions on every device mockup Apple renders it into.
//
// Written against AVFoundation instead of shelling out to ffmpeg so the machine
// needs nothing installed.
//
// usage: swift trim.swift <in.mov> <out.mov> <startSeconds> <durationSeconds>

import AVFoundation
import Foundation

let args = CommandLine.arguments
guard args.count == 5,
      let start = Double(args[3]), let dur = Double(args[4]) else {
    FileHandle.standardError.write("usage: trim.swift <in> <out> <start> <duration>\n".data(using: .utf8)!)
    exit(2)
}
let inURL = URL(fileURLWithPath: args[1])
let outURL = URL(fileURLWithPath: args[2])
try? FileManager.default.removeItem(at: outURL)

let target = CGSize(width: 886, height: 1920)
let asset = AVURLAsset(url: inURL)

let sem = DispatchSemaphore(value: 0)
var failure: String?

Task {
    do {
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            failure = "no video track"; sem.signal(); return
        }
        let natural = try await track.load(.naturalSize)
        let prefer  = try await track.load(.preferredTransform)
        let assetDur = try await asset.load(.duration)

        // Scale to FILL, then centre the overflow.
        let sx = target.width / natural.width
        let sy = target.height / natural.height
        let scale = max(sx, sy)
        let scaled = CGSize(width: natural.width * scale, height: natural.height * scale)
        let tx = (target.width - scaled.width) / 2
        let ty = (target.height - scaled.height) / 2

        let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        layer.setTransform(prefer
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: tx, y: ty)), at: .zero)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.layerInstructions = [layer]

        let comp = AVMutableVideoComposition()
        comp.renderSize = target
        comp.frameDuration = CMTime(value: 1, timescale: 30)   // Apple: 30fps
        instruction.timeRange = CMTimeRange(start: .zero, duration: assetDur)
        comp.instructions = [instruction]

        guard let export = AVAssetExportSession(asset: asset,
                                                presetName: AVAssetExportPresetHighestQuality) else {
            failure = "no export session"; sem.signal(); return
        }
        export.videoComposition = comp
        export.outputURL = outURL
        export.outputFileType = .mov
        export.timeRange = CMTimeRange(
            start: CMTime(seconds: start, preferredTimescale: 600),
            duration: CMTime(seconds: dur, preferredTimescale: 600))

        await export.export()
        if export.status != .completed {
            failure = export.error?.localizedDescription ?? "export status \(export.status.rawValue)"
        }
        sem.signal()
    } catch {
        failure = error.localizedDescription
        sem.signal()
    }
}

sem.wait()
if let failure {
    FileHandle.standardError.write("FAILED: \(failure)\n".data(using: .utf8)!)
    exit(1)
}
print("wrote \(outURL.path)")
