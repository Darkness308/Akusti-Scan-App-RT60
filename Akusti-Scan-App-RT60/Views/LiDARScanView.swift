//
//  LiDARScanView.swift
//  Akusti-Scan-App-RT60
//
//  LiDAR room scanning view
//

import SwiftUI
import ARKit

struct LiDARScanView: View {
    @State private var scanner = LiDARScanner()
    @State private var showNotSupportedAlert = false

    @Binding var room: Room
    var onComplete: ((RoomDimensions) -> Void)?

    var body: some View {
        VStack(spacing: 24) {
            // Header
            headerSection

            Spacer()

            // Scan visualization
            scanVisualization

            // Progress
            if scanner.isScanning {
                progressSection
            }

            // Results
            if let dimensions = scanner.currentDimensions {
                resultsSection(dimensions)
            }

            Spacer()

            // Scan Button
            scanButton

            // Manual input option
            if !scanner.isScanning && scanner.currentDimensions == nil {
                manualInputButton
            }
        }
        .padding()
        .navigationTitle("LiDAR Scan")
        .alert("LiDAR nicht verfügbar", isPresented: $showNotSupportedAlert) {
            Button("OK") {}
        } message: {
            Text("Dieses Gerät unterstützt kein LiDAR. Bitte geben Sie die Raummaße manuell ein.")
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "camera.metering.matrix")
                .font(.system(size: 50))
                .foregroundStyle(.purple)

            Text("Raum scannen")
                .font(.headline)

            Text("Bewegen Sie das Gerät langsam durch den Raum")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var scanVisualization: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.8))

            if scanner.isScanning {
                // Scanning animation
                VStack(spacing: 16) {
                    ZStack {
                        ForEach(0..<3) { i in
                            Circle()
                                .stroke(Color.purple.opacity(0.5), lineWidth: 2)
                                .scaleEffect(scanner.isScanning ? 1.5 : 0.5)
                                .opacity(scanner.isScanning ? 0 : 1)
                                .animation(
                                    .easeOut(duration: 1.5)
                                    .repeatForever(autoreverses: false)
                                    .delay(Double(i) * 0.5),
                                    value: scanner.isScanning
                                )
                        }

                        Image(systemName: "viewfinder")
                            .font(.system(size: 60))
                            .foregroundStyle(.purple)
                    }

                    Text("\(scanner.pointCount) Punkte")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white)
                }
            } else if let dimensions = scanner.currentDimensions {
                // Show room dimensions
                VStack(spacing: 8) {
                    Image(systemName: "cube.transparent")
                        .font(.system(size: 50))
                        .foregroundStyle(.green)

                    Text(dimensions.formattedDimensions)
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text(dimensions.formattedVolume)
                        .font(.title2.bold())
                        .foregroundStyle(.green)
                }
            } else {
                // Ready state
                VStack(spacing: 8) {
                    Image(systemName: "camera.metering.spot")
                        .font(.system(size: 50))
                        .foregroundStyle(.gray)

                    Text("Bereit zum Scannen")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                }
            }
        }
        .frame(height: 200)
    }

    private var progressSection: some View {
        VStack(spacing: 8) {
            ProgressView(value: scanner.scanProgress)
                .tint(.purple)

            Text(String(format: "%.0f%% abgeschlossen", scanner.scanProgress * 100))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    private func resultsSection(_ dimensions: RoomDimensions) -> some View {
        VStack(spacing: 12) {
            Text("Erkannte Raummaße")
                .font(.headline)

            HStack(spacing: 20) {
                dimensionCard(label: "Länge", value: dimensions.length, unit: "m")
                dimensionCard(label: "Breite", value: dimensions.width, unit: "m")
                dimensionCard(label: "Höhe", value: dimensions.height, unit: "m")
            }

            HStack(spacing: 20) {
                dimensionCard(label: "Volumen", value: dimensions.volume, unit: "m³")
                dimensionCard(label: "Oberfläche", value: dimensions.surfaceArea, unit: "m²")
            }

            Button("Übernehmen") {
                applyDimensions(dimensions)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func dimensionCard(label: String, value: Float, unit: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(String(format: "%.2f %@", value, unit))
                .font(.subheadline.monospacedDigit())
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity)
    }

    private var scanButton: some View {
        Button {
            toggleScan()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: scanner.isScanning ? "stop.fill" : "camera.metering.matrix")
                    .font(.title2)

                Text(scanner.isScanning ? "Scan beenden" : "Scan starten")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(scanner.isScanning ? Color.red : Color.purple)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var manualInputButton: some View {
        NavigationLink {
            RoomEditorView(room: $room)
        } label: {
            HStack {
                Image(systemName: "square.and.pencil")
                Text("Manuell eingeben")
            }
            .font(.subheadline)
            .foregroundStyle(.blue)
        }
    }

    // MARK: - Actions

    private func toggleScan() {
        if scanner.isScanning {
            if let dimensions = scanner.stopScanning() {
                onComplete?(dimensions)
            }
        } else {
            guard LiDARScanner.isSupported else {
                showNotSupportedAlert = true
                return
            }

            do {
                try scanner.startScanning()
            } catch {
                // Handle error
            }
        }
    }

    private func applyDimensions(_ dimensions: RoomDimensions) {
        room = Room.fromLiDAR(dimensions: dimensions, name: room.name)
        room.createDefaultSurfaces(
            floorMaterial: .woodFloor,
            ceilingMaterial: .plasterOnBrick,
            wallMaterial: .plasterOnBrick
        )
        onComplete?(dimensions)
    }
}
