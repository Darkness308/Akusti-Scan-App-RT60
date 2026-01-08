//
//  ContentView.swift
//  Akusti-Scan-App-RT60
//
//  Created by Marc Schneider-Handrup on 03.11.25.
//

import SwiftUI

struct ContentView: View {
    @State private var audioRecorder = AudioRecorder()
    @State private var rt60Result: RT60Result?
    @State private var errorMessage: String?
    @State private var isProcessing = false

    private let rt60Calculator = RT60Calculator()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                headerView

                Spacer()

                // Level Meter
                levelMeterView

                // Result Display
                if let result = rt60Result {
                    resultView(result)
                }

                // Error Display
                if let error = errorMessage {
                    errorView(error)
                }

                Spacer()

                // Record Button
                recordButton
            }
            .padding()
            .navigationTitle("RT60 Scanner")
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.tint)

            Text("Nachhallzeit-Messung")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    private var levelMeterView: some View {
        VStack(spacing: 8) {
            // Audio level bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(levelColor)
                        .frame(width: levelWidth(for: geometry.size.width))
                }
            }
            .frame(height: 20)

            Text(audioRecorder.isRecording ? "Aufnahme läuft..." : "Bereit")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func resultView(_ result: RT60Result) -> some View {
        VStack(spacing: 16) {
            Text("RT60")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(result.formattedRT60)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            HStack(spacing: 24) {
                if let t20 = result.t20 {
                    metricView(title: "T20", value: String(format: "%.2f s", t20))
                }
                if let t30 = result.t30 {
                    metricView(title: "T30", value: String(format: "%.2f s", t30))
                }
                if let edt = result.edt {
                    metricView(title: "EDT", value: String(format: "%.2f s", edt))
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func metricView(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }

    private func errorView(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var recordButton: some View {
        Button {
            Task {
                await toggleRecording()
            }
        } label: {
            HStack {
                if isProcessing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: audioRecorder.isRecording ? "stop.fill" : "mic.fill")
                }
                Text(buttonTitle)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(buttonColor)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isProcessing)
    }

    // MARK: - Computed Properties

    private var buttonTitle: String {
        if isProcessing {
            return "Verarbeite..."
        }
        return audioRecorder.isRecording ? "Stoppen" : "Messung starten"
    }

    private var buttonColor: Color {
        audioRecorder.isRecording ? .red : .blue
    }

    private var levelColor: Color {
        let level = audioRecorder.currentLevel
        if level > -10 { return .red }
        if level > -20 { return .orange }
        return .green
    }

    private func levelWidth(for totalWidth: CGFloat) -> CGFloat {
        // Convert dB level (-60 to 0) to width percentage
        let normalized = (audioRecorder.currentLevel + 60) / 60
        return totalWidth * CGFloat(max(0, min(1, normalized)))
    }

    // MARK: - Actions

    private func toggleRecording() async {
        errorMessage = nil

        if audioRecorder.isRecording {
            // Stop and process
            isProcessing = true
            let samples = audioRecorder.stopRecording()

            do {
                rt60Result = try rt60Calculator.calculateRT60(from: samples)
            } catch {
                errorMessage = error.localizedDescription
            }

            isProcessing = false
        } else {
            // Start recording
            do {
                try await audioRecorder.startRecording()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    ContentView()
}
