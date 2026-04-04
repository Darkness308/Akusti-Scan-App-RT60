import Foundation

@MainActor
final class DependencyContainer {
    static let shared = DependencyContainer()

    // Services
    lazy var audioRecorder: AudioRecording = AudioRecorder()
    lazy var rt60Calculator: RT60Calculating = RT60Calculator()

    private init() {}
}
