import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let CHANNEL = "dictapro/convert"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as! FlutterViewController

    let channel = FlutterMethodChannel(name: CHANNEL, binaryMessenger: controller.binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "convertToWav":
        guard let args = call.arguments as? [String: Any],
              let inputPath = args["inputPath"] as? String,
              let outputPath = args["outputPath"] as? String else {
          result(FlutterError(code: "INVALID_ARGUMENTS", message: "inputPath or outputPath is null", details: nil))
          return
        }

        do {
          try self?.convertAudioToWav(inputPath: inputPath, outputPath: outputPath, targetSampleRate: 16000, targetChannels: 1)
          result(["success": true])
        } catch {
          result(["success": false, "error": error.localizedDescription])
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func convertAudioToWav(inputPath: String, outputPath: String, targetSampleRate: Int, targetChannels: Int) throws {
    let inputURL = URL(fileURLWithPath: inputPath)
    let asset = AVAsset(url: inputURL)

    guard let audioTrack = asset.tracks(withMediaType: .audio).first else {
      throw NSError(domain: "DictaPro", code: 1, userInfo: [NSLocalizedDescriptionKey: "No audio track found"])
    }

    let reader = try AVAssetReader(asset: asset)
    let outputSettings: [String: Any] = [
      AVFormatIDKey: Int(kAudioFormatLinearPCM),
      AVLinearPCMBitDepthKey: 16,
      AVLinearPCMIsBigEndianKey: false,
      AVLinearPCMIsFloatKey: false,
      AVSampleRateKey: targetSampleRate,
      AVNumberOfChannelsKey: targetChannels
    ]

    let trackOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
    reader.add(trackOutput)
    reader.startReading()

    var pcmData = Data()
    while reader.status == .reading {
      guard let sampleBuffer = trackOutput.copyNextSampleBuffer() else { break }
      if let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) {
        let length = CMBlockBufferGetDataLength(blockBuffer)
        var data = Data(count: length)
        data.withUnsafeMutableBytes { ptr in
          if let baseAddress = ptr.baseAddress {
            CMBlockBufferCopyDataBytes(blockBuffer, 0, length, baseAddress)
          }
        }
        pcmData.append(data)
      }
    }

    if reader.status == .failed {
      throw reader.error ?? NSError(domain: "DictaPro", code: 2, userInfo: [NSLocalizedDescriptionKey: "Audio decoding failed"])
    }

    try writeWavFile(outputPath: outputPath, pcmData: pcmData, sampleRate: targetSampleRate, channels: targetChannels, bitsPerSample: 16)
  }

  private func writeWavFile(outputPath: String, pcmData: Data, sampleRate: Int, channels: Int, bitsPerSample: Int) throws {
    let byteRate = sampleRate * channels * bitsPerSample / 8
    let totalDataLen = pcmData.count + 36

    var header = Data()
    header.append(contentsOf: "RIFF".utf8)
    header.append(contentsOf: UInt32(totalDataLen).littleEndian.bytes)
    header.append(contentsOf: "WAVE".utf8)
    header.append(contentsOf: "fmt ".utf8)
    header.append(contentsOf: UInt32(16).littleEndian.bytes)
    header.append(contentsOf: UInt16(1).littleEndian.bytes)
    header.append(contentsOf: UInt16(channels).littleEndian.bytes)
    header.append(contentsOf: UInt32(sampleRate).littleEndian.bytes)
    header.append(contentsOf: UInt32(byteRate).littleEndian.bytes)
    header.append(contentsOf: UInt16(channels * bitsPerSample / 8).littleEndian.bytes)
    header.append(contentsOf: UInt16(bitsPerSample).littleEndian.bytes)
    header.append(contentsOf: "data".utf8)
    header.append(contentsOf: UInt32(pcmData.count).littleEndian.bytes)

    let outputURL = URL(fileURLWithPath: outputPath)
    var fileData = header
    fileData.append(pcmData)
    try fileData.write(to: outputURL)
  }
}

extension FixedWidthInteger {
  var bytes: [UInt8] {
    var value = self
    return withUnsafeBytes(of: &value) { Array($0) }
  }
}
