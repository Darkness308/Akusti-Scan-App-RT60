import Foundation
import Combine

@MainActor
protocol AudioRecording: AnyObject {
    var state: RecorderState { get }
    var currentLevel: Float { get }
    var peakLevel: Float { get }
    var isImpulseDetected: Bool { get }

    var statePublisher: AnyPublisher<RecorderState, Never> { get }
    var currentLevelPublisher: AnyPublisher<Float, Never> { get }
    var peakLevelPublisher: AnyPublisher<Float, Never> { get }
    var isImpulseDetectedPublisher: AnyPublisher<Bool, Never> { get }

    func requestPermission() async -> Bool
    func startRecording() async throws
    func stopRecording()
    func reset()
    func getAudioSample() -> AudioSample
}
