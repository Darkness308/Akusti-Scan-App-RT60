//
//  HistoryView.swift
//  Akusti-Scan-App-RT60
//
//  Measurement history and statistics view
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MeasurementRecord.timestamp, order: .reverse) private var measurements: [MeasurementRecord]

    @State private var showDeleteConfirmation = false
    @State private var selectedMeasurement: MeasurementRecord?

    var body: some View {
        List {
            // Statistics Section
            if !measurements.isEmpty {
                statisticsSection
            }

            // Measurements Section
            Section("Messungen") {
                if measurements.isEmpty {
                    emptyStateView
                } else {
                    ForEach(measurements) { measurement in
                        measurementRow(measurement)
                    }
                    .onDelete(perform: deleteMeasurements)
                }
            }
        }
        .navigationTitle("Verlauf")
        .toolbar {
            if !measurements.isEmpty {
                ToolbarItem(placement: .destructiveAction) {
                    Button("Alle löschen", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                }
            }
        }
        .alert("Alle Messungen löschen?", isPresented: $showDeleteConfirmation) {
            Button("Abbrechen", role: .cancel) {}
            Button("Löschen", role: .destructive) {
                deleteAllMeasurements()
            }
        } message: {
            Text("Diese Aktion kann nicht rückgängig gemacht werden.")
        }
        .sheet(item: $selectedMeasurement) { measurement in
            MeasurementDetailView(measurement: measurement)
        }
    }

    // MARK: - Sections

    private var statisticsSection: some View {
        Section("Statistik") {
            let stats = calculateStatistics()

            HStack {
                StatCard(title: "Messungen", value: "\(stats.count)", icon: "number")
                StatCard(title: "Ø RT60", value: stats.avgRT60, icon: "waveform")
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            HStack {
                StatCard(title: "Min", value: stats.minRT60, icon: "arrow.down")
                StatCard(title: "Max", value: stats.maxRT60, icon: "arrow.up")
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("Keine Messungen")
                .font(.headline)

            Text("Führen Sie eine RT60-Messung durch, um sie hier zu speichern.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func measurementRow(_ measurement: MeasurementRecord) -> some View {
        Button {
            selectedMeasurement = measurement
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(measurement.roomName)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(measurement.formattedDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(measurement.formattedRT60)
                        .font(.title3.bold())
                        .foregroundStyle(.blue)

                    Text(String(format: "%.1f m³", measurement.roomVolume))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Statistics

    private func calculateStatistics() -> (count: Int, avgRT60: String, minRT60: String, maxRT60: String) {
        guard !measurements.isEmpty else {
            return (0, "-", "-", "-")
        }

        let rt60Values = measurements.map { $0.primaryRT60 }
        let avg = rt60Values.reduce(0, +) / Double(rt60Values.count)

        return (
            count: measurements.count,
            avgRT60: String(format: "%.2f s", avg),
            minRT60: String(format: "%.2f s", rt60Values.min() ?? 0),
            maxRT60: String(format: "%.2f s", rt60Values.max() ?? 0)
        )
    }

    // MARK: - Actions

    private func deleteMeasurements(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(measurements[index])
        }
    }

    private func deleteAllMeasurements() {
        for measurement in measurements {
            modelContext.delete(measurement)
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.bold())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Measurement Detail View

struct MeasurementDetailView: View {
    let measurement: MeasurementRecord
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Raum") {
                    LabeledContent("Name", value: measurement.roomName)
                    LabeledContent("Volumen", value: String(format: "%.1f m³", measurement.roomVolume))
                    LabeledContent("Oberfläche", value: String(format: "%.1f m²", measurement.roomSurfaceArea))
                    LabeledContent("Abmessungen", value: String(format: "%.1f × %.1f × %.1f m", measurement.roomLength, measurement.roomWidth, measurement.roomHeight))
                }

                Section("RT60 Werte") {
                    if let measured = measurement.averageMeasuredRT60 {
                        LabeledContent("Gemessen", value: String(format: "%.2f s", measured))
                    }
                    LabeledContent("Sabine", value: String(format: "%.2f s", measurement.averageSabineRT60))
                    LabeledContent("Eyring", value: String(format: "%.2f s", measurement.averageEyringRT60))
                }

                Section("Frequenzbänder") {
                    let bands = measurement.measuredRT60 ?? measurement.sabineRT60
                    ForEach(FrequencyBand.allCases, id: \.self) { band in
                        if let value = bands[band] {
                            LabeledContent(band.rawValue, value: String(format: "%.2f s", value))
                        }
                    }
                }

                Section("Bewertung") {
                    Text(measurement.qualityAssessment)
                        .foregroundStyle(.secondary)
                }

                Section("Zeitpunkt") {
                    LabeledContent("Datum", value: measurement.formattedDate)
                }
            }
            .navigationTitle("Messung Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}
