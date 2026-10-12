//
//  ReplayRenderer.swift
//  Hunch
//
//  Solve Replay (3.4), part 4: frames to an .mp4 file.
//
//  Draws every frame offscreen with ReplayScene and hands it straight to
//  AVAssetWriter: 1080 x 1920, 30 frames per second, H.264. No screen
//  recording and no third-party code. It runs on a background task, and a
//  60 second replay is 1,800 frames, so it reports progress as it goes and
//  stops promptly if the task is cancelled (the sheet was closed).
//

import AVFoundation
import CoreGraphics
import CoreVideo
import Foundation

nonisolated enum ReplayRenderer {

    static let framesPerSecond: Int32 = 30

    nonisolated enum Failure: Error {
        case cannotAddInput
        case noPixelBuffer
        case writer(String)
    }

    /// Renders the replay to `url`, replacing any file already there.
    /// `progress` is called with 0...1 from the background task.
    static func render(_ request: ReplayRequest, to url: URL,
                       progress: @escaping @Sendable (Double) -> Void) async throws {
        try? FileManager.default.removeItem(at: url)

        let size = ReplayScene.size
        let width = Int(size.width), height = Int(size.height)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)

        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                // Flat colors and text: 10 Mbps keeps edges crisp after the
                // upload site re-encodes it.
                AVVideoAverageBitRateKey: 10_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoExpectedSourceFrameRateKey: Int(framesPerSecond),
                AVVideoMaxKeyFrameIntervalKey: Int(framesPerSecond),
            ] as [String: Any],
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
            ],
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
                kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
                kCVPixelBufferCGImageCompatibilityKey as String: true,
            ])

        guard writer.canAdd(input) else { throw Failure.cannotAddInput }
        writer.add(input)
        guard writer.startWriting() else {
            throw Failure.writer(writer.error?.localizedDescription ?? "startWriting failed")
        }
        writer.startSession(atSourceTime: .zero)

        let scene = ReplayScene(request: request)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let frameCount = max(1, Int((request.timeline.duration * Double(framesPerSecond)).rounded(.up)))

        do {
            for frame in 0..<frameCount {
                try Task.checkCancellation()
                while !input.isReadyForMoreMediaData {
                    try Task.checkCancellation()
                    try await Task.sleep(for: .milliseconds(5))
                }

                guard let pool = adaptor.pixelBufferPool else { throw Failure.noPixelBuffer }
                var made: CVPixelBuffer?
                CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &made)
                guard let buffer = made else { throw Failure.noPixelBuffer }

                CVPixelBufferLockBaseAddress(buffer, [])
                autoreleasepool {
                    if let ctx = CGContext(
                        data: CVPixelBufferGetBaseAddress(buffer),
                        width: width, height: height, bitsPerComponent: 8,
                        bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                        space: colorSpace,
                        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                            | CGBitmapInfo.byteOrder32Little.rawValue) {
                        scene.draw(in: ctx, at: Double(frame) / Double(framesPerSecond))
                    }
                }
                CVPixelBufferUnlockBaseAddress(buffer, [])

                let time = CMTime(value: CMTimeValue(frame), timescale: framesPerSecond)
                guard adaptor.append(buffer, withPresentationTime: time) else {
                    throw Failure.writer(writer.error?.localizedDescription ?? "append failed")
                }
                if frame % 10 == 0 { progress(Double(frame) / Double(frameCount)) }
            }
        } catch {
            writer.cancelWriting()
            try? FileManager.default.removeItem(at: url)
            throw error
        }

        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else {
            try? FileManager.default.removeItem(at: url)
            throw Failure.writer(writer.error?.localizedDescription ?? "finishWriting failed")
        }
        progress(1)
    }
}
