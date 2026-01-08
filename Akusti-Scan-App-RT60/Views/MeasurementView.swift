//
//  MeasurementView.swift
//  Akusti-Scan-App-RT60
//
//  Audio measurement view for RT60 recording
//

import SwiftUI
import SwiftData

struct MeasurementView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var audioRecorder = AudioRecorder()
    @State private var sweptSineGenerator = SweptSineGenerator()
    @State private var analysisResult: AcousticAnalysis?
    @State private var errorMessage: String?
    @State private var isProcessing = false
    @State private var showShareSheet = false
    @State private var pdfURL: URL?
    @State private var showSaveConfirmation = false
    @State private var measurementMethod: MeasurementMethod = .impulse

    @Binding var room: Room
    private let acousticsCalculator = AcousticsCalculator()
    private let reportGenerator = ReportGenerator()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection

                // Level Meter
                levelMeterSection

                // Record Button
                recordButton

                // Results
                if let result = analysisResult {
                    resultsSection(result)
                    exportButton(result)
                }

                // Error
                if let error = errorMessage {
                    errorView(error)
                }
            }
            .padding()
        }
        .navigationTitle("Messung")
        .sheet(isPresented: $showShareSheet) {
            if let url = pdfURL {
                ShareSheet(activityItems: [url])
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.blue)

            Text("RT60 Messung")
                .font(.headline)

            Text("Raum: \(room.name)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(String(format: "%.1f m³", room.volume))
                .font(.caption)
                .foregroundStyle(.secondary)

            // Method Selection
            VStack(spacing: 8) {
                Text("Messmethode")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Methode", selection: $measurementMethod) {
                    ForEach(MeasurementMethod.allCases) { method in
                        Text(method.rawValue).tag(method)
                    }
                }
                .pickerStyle(.segmented)

                Text(measurementMethod.description)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)
        }
        .padding()
    }

    private var levelMeterSection: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))

                    if measurementMethod == .sweptSine {
                        // Progress bar for swept sine
                        RoundedRectangle(cornerRadius: 6)
                            .fill(sweptSineGenerator.isPlaying ? Color.orange : Color.blue)
                            .frame(width: geometry.size.width * CGFloat(sweptSineGenerator.progress))
                            .animation(.easeOut(duration: 0.1), value: sweptSineGenerator.progress)
                    } else {
                        // Level meter for impulse
                        RoundedRectangle(cornerRadius: 6)
                            .fill(levelColor)
                            .frame(width: levelWidth(for: geometry.size.width))
                            .animation(.easeOut(duration: 0.1), value: audioRecorder.currentLevel)
                    }
                }
            }
            .frame(height: 24)

            HStack {
                if measurementMethod == .sweptSine {
                    Text(sweptSineStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(audioRecorder.isRecording ? "Aufnahme läuft..." : "Bereit")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if measurementMethod == .impulse {
                    Text(String(format: "%.1f dB", audioRecorder.currentLevel))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    Text(String(format: "%.0f%%", sweptSineGenerator.progress * 100))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal)
    }

    private var sweptSineStatusText: String {
        if sweptSineGenerator.isPlaying {
            return "Sweep wird abgespielt..."
        } else if sweptSineGenerator.isRecording {
            return "Raumantwort wird aufgenommen..."
        } else {
            return "Bereit für Swept Sine Messung"
        }
    }

    private var recordButton: some View {
        Button {
            Task { await toggleRecording() }
        } label: {
            HStack(spacing: 12) {
                if isProcessing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: audioRecorder.isRecording ? "stop.fill" : "mic.fill")
                        .font(.title2)
                }

                Text(buttonTitle)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(buttonColor)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(isProcessing)
        .padding(.horizontal)
    }

    private func resultsSection(_ result: AcousticAnalysis) -> some View {
        VStack(spacing: 16) {
            // Main RT60 value
            VStack(spacing: 4) {
                Text("RT60")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(String(format: "%.2f s", result.averageMeasuredRT60 ?? result.averageSabineRT60))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
            }

            // Quality assessment
            Text(result.qualityAssessment)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Divider()

            // Frequency bands
            VStack(alignment: .leading, spacing: 12) {
                Text("Nach Frequenzband")
                    .font(.headline)

                ForEach(FrequencyBand.allCases, id: \.self) { band in
                    frequencyBandRow(band: band, result: result)
                }
            }

            Divider()

            // Comparison
            HStack(spacing: 20) {
                comparisonCard(title: "Sabine", value: result.averageSabineRT60)
                comparisonCard(title: "Eyring", value: result.averageEyringRT60)
                if let measured = result.averageMeasuredRT60 {
                    comparisonCard(title: "Gemessen", value: measured, highlight: true)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private func frequencyBandRow(band: FrequencyBand, result: AcousticAnalysis) -> some View {
        HStack {
            Text(band.rawValue)
                .font(.caption)
                .frame(width: 60, alignment: .leading)

            GeometryReader { geometry in
                let maxRT60 = 3.0
                let measured = result.measuredRT60?[band] ?? 0
                let sabine = result.sabineRT60[band] ?? 0

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue.opacity(0.5))
                        .frame(width: geometry.size.width * CGFloat(sabine / maxRT60))

                    if measured > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.green)
                            .frame(width: geometry.size.width * CGFloat(measured / maxRT60))
                    }
                }
            }
            .frame(height: 16)

            Text(String(format: "%.2f s", result.measuredRT60?[band] ?? result.sabineRT60[band] ?? 0))
                .font(.caption.monospacedDigit())
                .frame(width: 50, alignment: .trailing)
        }
    }

    private func comparisonCard(title: String, value: Double, highlight: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(String(format: "%.2f s", value))
                .font(.subheadline)
                .fontWeight(highlight ? .bold : .regular)
                .foregroundStyle(highlight ? .green : .primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(highlight ? Color.green.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func exportButton(_ result: AcousticAnalysis) -> some View {
        VStack(spacing: 12) {
            // Save Button
            Button {
                saveMeasurement(result)
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                    Text("Messung speichern")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green.opacity(0.1))
                .foregroundStyle(.green)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Export Button
            Button {
                exportPDF(result)
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("PDF Report exportieren")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .foregroundStyle(.blue)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal)
        .alert("Gespeichert", isPresented: $showSaveConfirmation) {
            Button("OK") {}
        } message: {
            Text("Die Messung wurde im Verlauf gespeichert.")
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
        .frame(maxWidth: .infinity)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
    }

    // MARK: - Computed Properties

    private var buttonTitle: String {
        if isProcessing { return "Verarbeite..." }

        switch measurementMethod {
        case .impulse:
            return audioRecorder.isRecording ? "Stoppen & Analysieren" : "Aufnahme starten"
        case .sweptSine:
            if sweptSineGenerator.isPlaying || sweptSineGenerator.isRecording {
                return "Messung läuft..."
            }
            return "Swept Sine starten"
        }
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
        let normalized = (audioRecorder.currentLevel + 60) / 60
        return totalWidth * CGFloat(max(0, min(1, normalized)))
    }

    // MARK: - Actions

    private func toggleRecording() async {
        errorMessage = nil

        switch measurementMethod {
        case .impulse:
            await performImpulseMeasurement()
        case .sweptSine:
            await performSweptSineMeasurement()
        }
    }

    private func performImpulseMeasurement() async {
        if audioRecorder.isRecording {
            isProcessing = true
            let samples = audioRecorder.stopRecording()

            // Extract impulse response from recording
            if let irSamples = sweptSineGenerator.extractImpulseResponse(samples: samples) {
                let result = acousticsCalculator.analyzeRoom(room: room, audioSamples: irSamples)
                analysisResult = result
            } else {
                // Fallback: use raw samples if no impulse detected
                let result = acousticsCalculator.analyzeRoom(room: room, audioSamples: samples)
                analysisResult = result
                errorMessage = "Kein deutlicher Impuls erkannt. Ergebnisse basieren auf Rohaufnahme."
            }

            isProcessing = false
        } else {
            do {
                try await audioRecorder.startRecording()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func performSweptSineMeasurement() async {
        guard !sweptSineGenerator.isPlaying && !sweptSineGenerator.isRecording else { return }

        isProcessing = true

        do {
            let impulseResponse = try await sweptSineGenerator.measureWithSweep()

            let result = acousticsCalculator.analyzeRoom(room: room, audioSamples: impulseResponse)
            analysisResult = result
        } catch {
            errorMessage = "Swept Sine Messung fehlgeschlagen: \(error.localizedDescription)"
        }

        isProcessing = false
    }

    private func exportPDF(_ result: AcousticAnalysis) {
        if let url = reportGenerator.sharePDF(analysis: result, room: room) {
            pdfURL = url
            showShareSheet = true
        }
    }

    private func saveMeasurement(_ result: AcousticAnalysis) {
        let record = MeasurementRecord(from: result, room: room)
        modelContext.insert(record)
        try? modelContext.save()
        showSaveConfirmation = true
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
