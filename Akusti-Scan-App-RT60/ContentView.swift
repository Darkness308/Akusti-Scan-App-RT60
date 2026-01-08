//
//  ContentView.swift
//  Akusti-Scan-App-RT60
//
//  Created by Marc Schneider-Handrup on 03.11.25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = RT60ViewModel()
    @State private var showSettings = false
    @State private var showHistory = false
    @State private var showExport = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header mit Status
                    StatusHeaderView(viewModel: viewModel)

                    // Level-Meter
                    LevelMeterView(
                        currentLevel: viewModel.currentLevel,
                        peakLevel: viewModel.peakLevel,
                        state: viewModel.measurementState
                    )

                    // Haupt-Ergebnis
                    if viewModel.latestMeasurement != nil {
                        ResultCardView(viewModel: viewModel)
                    }

                    // Decay-Kurve
                    if let curve = viewModel.decayCurve, !curve.timePoints.isEmpty {
                        DecayCurveView(curve: curve)
                    }

                    // Frequenzband-Analyse
                    if viewModel.showBandAnalysis && !viewModel.bandMeasurements.isEmpty {
                        BandAnalysisView(measurements: viewModel.bandMeasurements)
                    }

                    // Steuerungs-Buttons
                    ControlButtonsView(viewModel: viewModel)

                    // Raumtyp-Auswahl
                    RoomTypePickerView(selectedRoomType: $viewModel.selectedRoomType)

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Akusti-Scan RT60")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Toggle("Frequenzband-Analyse", isOn: $viewModel.showBandAnalysis)

                        Button {
                            showExport = true
                        } label: {
                            Label("Exportieren", systemImage: "square.and.arrow.up")
                        }
                        .disabled(viewModel.latestMeasurement == nil)

                        Button {
                            showSettings = true
                        } label: {
                            Label("Einstellungen", systemImage: "gear")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showHistory) {
                HistoryView(measurements: viewModel.measurementHistory) {
                    viewModel.clearHistory()
                }
            }
            .sheet(isPresented: $showExport) {
                ExportView(exportText: viewModel.exportResults())
            }
            .alert("Fehler", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .task {
                await viewModel.checkPermission()
            }
        }
    }
}

// MARK: - Status Header View

struct StatusHeaderView: View {
    @ObservedObject var viewModel: RT60ViewModel

    var body: some View {
        HStack {
            Circle()
                .fill(viewModel.measurementState.color)
                .frame(width: 12, height: 12)

            Text(viewModel.measurementState.displayText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            if viewModel.measurementState == .recording {
                Image(systemName: "waveform")
                    .foregroundStyle(.red)
                    .symbolEffect(.pulse)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Level Meter View

struct LevelMeterView: View {
    let currentLevel: Float
    let peakLevel: Float
    let state: MeasurementState

    private var normalizedLevel: Double {
        let minDB: Float = -60
        let maxDB: Float = 0
        let clamped = max(minDB, min(maxDB, currentLevel))
        return Double((clamped - minDB) / (maxDB - minDB))
    }

    var body: some View {
        VStack(spacing: 8) {
            // Level-Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Hintergrund
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))

                    // Level
                    RoundedRectangle(cornerRadius: 4)
                        .fill(levelColor)
                        .frame(width: geometry.size.width * normalizedLevel)
                        .animation(.linear(duration: 0.05), value: normalizedLevel)
                }
            }
            .frame(height: 20)

            // dB-Werte
            HStack {
                Text("\(Int(currentLevel)) dB")
                    .font(.caption)
                    .monospacedDigit()

                Spacer()

                Text("Peak: \(Int(peakLevel)) dB")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var levelColor: Color {
        if currentLevel > -6 {
            return .red
        } else if currentLevel > -12 {
            return .orange
        } else if currentLevel > -24 {
            return .yellow
        } else {
            return .green
        }
    }
}

// MARK: - Result Card View

struct ResultCardView: View {
    @ObservedObject var viewModel: RT60ViewModel

    var body: some View {
        VStack(spacing: 16) {
            // Haupt-RT60-Wert
            VStack(spacing: 4) {
                Text("RT60")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(viewModel.formattedRT60)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(resultColor)
            }

            // Bewertung
            if let rating = viewModel.acousticRating {
                HStack {
                    Image(systemName: ratingIcon(rating))
                        .foregroundStyle(ratingColor(rating))

                    Text(rating.rawValue)
                        .font(.headline)
                        .foregroundStyle(ratingColor(rating))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(ratingColor(rating).opacity(0.1))
                .clipShape(Capsule())
            }

            // Optimaler Bereich
            Text("Optimal für \(viewModel.selectedRoomType.rawValue): \(viewModel.optimalRangeText)")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Details
            if let measurement = viewModel.latestMeasurement {
                Divider()

                HStack(spacing: 20) {
                    if let t20 = measurement.t20Value {
                        VStack {
                            Text("T20")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.2f s", t20))
                                .font(.caption)
                                .monospacedDigit()
                        }
                    }

                    if let t30 = measurement.t30Value {
                        VStack {
                            Text("T30")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.2f s", t30))
                                .font(.caption)
                                .monospacedDigit()
                        }
                    }

                    VStack {
                        Text("Peak")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.0f dB", measurement.peakLevel))
                            .font(.caption)
                            .monospacedDigit()
                    }

                    VStack {
                        Text("Noise")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.0f dB", measurement.noiseFloor))
                            .font(.caption)
                            .monospacedDigit()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }

    private var resultColor: Color {
        guard let rating = viewModel.acousticRating else { return .primary }
        return ratingColor(rating)
    }

    private func ratingColor(_ rating: RoomAcousticRating) -> Color {
        switch rating {
        case .tooDry: return .blue
        case .dry: return .cyan
        case .balanced: return .green
        case .live: return .orange
        case .tooLive: return .red
        }
    }

    private func ratingIcon(_ rating: RoomAcousticRating) -> String {
        switch rating {
        case .tooDry, .tooLive: return "exclamationmark.triangle.fill"
        case .dry, .live: return "info.circle.fill"
        case .balanced: return "checkmark.circle.fill"
        }
    }
}

// MARK: - Decay Curve View

struct DecayCurveView: View {
    let curve: DecayCurve

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Decay-Kurve")
                .font(.headline)

            GeometryReader { geometry in
                Path { path in
                    guard curve.timePoints.count > 1 else { return }

                    let width = geometry.size.width
                    let height = geometry.size.height

                    let maxTime = curve.timePoints.max() ?? 1
                    let minLevel = curve.levelPoints.min() ?? -60
                    let maxLevel = curve.levelPoints.max() ?? 0

                    for (index, time) in curve.timePoints.enumerated() {
                        let x = CGFloat(time / maxTime) * width
                        let normalizedLevel = (curve.levelPoints[index] - minLevel) / (maxLevel - minLevel)
                        let y = height - CGFloat(normalizedLevel) * height

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color.accentColor, lineWidth: 2)

                // Regressionslinie
                Path { path in
                    guard curve.timePoints.count > 1 else { return }

                    let width = geometry.size.width
                    let height = geometry.size.height

                    let maxTime = curve.timePoints.max() ?? 1
                    let minLevel = curve.levelPoints.min() ?? -60
                    let maxLevel = curve.levelPoints.max() ?? 0

                    let startY = curve.regressionIntercept
                    let endY = curve.regressionSlope * maxTime + curve.regressionIntercept

                    let normalizedStartY = (startY - minLevel) / (maxLevel - minLevel)
                    let normalizedEndY = (endY - minLevel) / (maxLevel - minLevel)

                    path.move(to: CGPoint(x: 0, y: height - CGFloat(normalizedStartY) * height))
                    path.addLine(to: CGPoint(x: width, y: height - CGFloat(normalizedEndY) * height))
                }
                .stroke(Color.red.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
            }
            .frame(height: 150)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Korrelationsanzeige
            HStack {
                Text("Korrelation: \(String(format: "%.3f", curve.correlationCoefficient))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("Slope: \(String(format: "%.1f", curve.regressionSlope)) dB/s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Band Analysis View

struct BandAnalysisView: View {
    let measurements: [FrequencyBand: RT60Measurement]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Frequenzband-Analyse")
                .font(.headline)

            ForEach(FrequencyBand.allCases, id: \.self) { band in
                if let measurement = measurements[band], measurement.isValid {
                    HStack {
                        Text(band.rawValue)
                            .font(.subheadline)
                            .frame(width: 80, alignment: .leading)

                        GeometryReader { geometry in
                            let maxRT60 = 3.0
                            let width = min(CGFloat(measurement.rt60Value / maxRT60), 1.0) * geometry.size.width

                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(.systemGray5))

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.accentColor)
                                    .frame(width: width)
                            }
                        }
                        .frame(height: 20)

                        Text(String(format: "%.2f s", measurement.rt60Value))
                            .font(.caption)
                            .monospacedDigit()
                            .frame(width: 60, alignment: .trailing)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Control Buttons View

struct ControlButtonsView: View {
    @ObservedObject var viewModel: RT60ViewModel

    var body: some View {
        HStack(spacing: 16) {
            // Reset-Button
            Button {
                viewModel.resetMeasurement()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.measurementState == .recording || viewModel.measurementState == .processing)

            // Haupt-Aktions-Button
            Button {
                Task {
                    if viewModel.measurementState == .recording {
                        viewModel.stopMeasurement()
                    } else {
                        await viewModel.startMeasurement()
                    }
                }
            } label: {
                Label(
                    viewModel.measurementState == .recording ? "Stopp" : "Messung starten",
                    systemImage: viewModel.measurementState == .recording ? "stop.fill" : "mic.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.measurementState == .processing || viewModel.measurementState == .permissionDenied)
        }
    }
}

// MARK: - Room Type Picker View

struct RoomTypePickerView: View {
    @Binding var selectedRoomType: RoomType

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Raumtyp")
                .font(.headline)

            Picker("Raumtyp", selection: $selectedRoomType) {
                ForEach(RoomType.allCases, id: \.self) { roomType in
                    Text(roomType.rawValue).tag(roomType)
                }
            }
            .pickerStyle(.segmented)

            Text("Optimaler RT60-Bereich: \(formatRange(selectedRoomType.optimalRT60Range))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatRange(_ range: ClosedRange<Double>) -> String {
        String(format: "%.1f - %.1f s", range.lowerBound, range.upperBound)
    }
}

// MARK: - History View

struct HistoryView: View {
    let measurements: [RT60Measurement]
    let onClear: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if measurements.isEmpty {
                    Text("Keine Messungen vorhanden")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(measurements) { measurement in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(String(format: "%.2f s", measurement.rt60Value))
                                    .font(.headline)

                                Text(formatDate(measurement.timestamp))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(measurement.frequency.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.systemGray5))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .navigationTitle("Messhistorie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Schliessen") {
                        dismiss()
                    }
                }

                if !measurements.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Loeschen", role: .destructive) {
                            onClear()
                        }
                    }
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Export View

struct ExportView: View {
    let exportText: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(exportText)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Schliessen") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: exportText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
