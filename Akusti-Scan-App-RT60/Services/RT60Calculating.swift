import Foundation

protocol RT60Calculating {
    func calculateRT60(from audioSample: AudioSample) -> RT60Measurement
    func calculateRT60ByBand(from audioSample: AudioSample) -> [FrequencyBand: RT60Measurement]
    func generateDecayCurve(from audioSample: AudioSample) -> DecayCurve
}
