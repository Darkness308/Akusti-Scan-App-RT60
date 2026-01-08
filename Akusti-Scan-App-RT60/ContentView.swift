//
//  ContentView.swift
//  Akusti-Scan-App-RT60
//
//  Created by Marc Schneider-Handrup on 03.11.25.
//

import SwiftUI

struct ContentView: View {
    @State private var room = Room(name: "Mein Raum")
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Home / Dashboard
            NavigationStack {
                HomeView(room: $room)
            }
            .tabItem {
                Label("Start", systemImage: "house.fill")
            }
            .tag(0)

            // LiDAR Scan
            NavigationStack {
                LiDARScanView(room: $room) { dimensions in
                    selectedTab = 2
                }
            }
            .tabItem {
                Label("Scan", systemImage: "camera.metering.matrix")
            }
            .tag(1)

            // Measurement
            NavigationStack {
                MeasurementView(room: $room)
            }
            .tabItem {
                Label("Messung", systemImage: "waveform")
            }
            .tag(2)

            // Room Editor
            NavigationStack {
                RoomEditorView(room: $room)
            }
            .tabItem {
                Label("Raum", systemImage: "square.split.bottomrightquarter")
            }
            .tag(3)
        }
    }
}

// MARK: - Home View

struct HomeView: View {
    @Binding var room: Room
    @State private var recentAnalysis: AcousticAnalysis?

    private let acousticsCalculator = AcousticsCalculator()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                roomInfoCard
                calculatedRT60Card
                quickActionsSection
                infoSection
            }
            .padding()
        }
        .navigationTitle("Akusti-Scan")
        .onAppear { calculatePreview() }
        .onChange(of: room.volume) { calculatePreview() }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("RT60 Akustik-Analyse")
                .font(.title2.bold())

            Text("Nachhallzeit-Messung und Raumakustik")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical)
    }

    private var roomInfoCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "cube.transparent")
                    .foregroundStyle(.blue)
                Text(room.name)
                    .font(.headline)
                Spacer()
                NavigationLink {
                    RoomEditorView(room: $room)
                } label: {
                    Image(systemName: "pencil")
                        .foregroundStyle(.blue)
                }
            }

            Divider()

            HStack(spacing: 20) {
                infoItem(title: "Volumen", value: String(format: "%.1f m³", room.volume), icon: "cube")
                infoItem(title: "Oberfläche", value: String(format: "%.1f m²", room.totalSurfaceArea), icon: "square.stack.3d.up")
            }

            HStack(spacing: 20) {
                infoItem(title: "L × B × H", value: String(format: "%.1f × %.1f × %.1f", room.length, room.width, room.height), icon: "ruler")
                infoItem(title: "Temperatur", value: String(format: "%.0f °C", room.temperature), icon: "thermometer.medium")
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var calculatedRT60Card: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "function")
                    .foregroundStyle(.purple)
                Text("Berechnete Nachhallzeit")
                    .font(.headline)
                Spacer()
            }

            if let analysis = recentAnalysis {
                HStack(spacing: 20) {
                    VStack {
                        Text("Sabine")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.2f s", analysis.averageSabineRT60))
                            .font(.title2.bold())
                            .foregroundStyle(.blue)
                    }

                    VStack {
                        Text("Eyring")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.2f s", analysis.averageEyringRT60))
                            .font(.title2.bold())
                            .foregroundStyle(.purple)
                    }
                }

                Text(analysis.qualityAssessment)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Color.purple.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Schnellaktionen")
                .font(.headline)

            HStack(spacing: 12) {
                QuickActionButton(title: "LiDAR Scan", icon: "camera.metering.matrix", color: .purple) {}
                QuickActionButton(title: "Messung", icon: "mic.fill", color: .green) {}
                QuickActionButton(title: "Report", icon: "doc.text", color: .orange) {}
            }
        }
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Über RT60")
                .font(.headline)

            Text("Die Nachhallzeit RT60 beschreibt die Zeit, die der Schalldruckpegel benötigt, um nach Abschalten der Schallquelle um 60 dB abzufallen.")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                infoRow(range: "< 0.5 s", desc: "Sprache, Heimkino")
                infoRow(range: "0.5 - 1.0 s", desc: "Mehrzweckräume")
                infoRow(range: "1.0 - 2.0 s", desc: "Konzertsäle")
                infoRow(range: "> 2.0 s", desc: "Kirchen, große Hallen")
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func infoItem(title: String, value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func infoRow(range: String, desc: String) -> some View {
        HStack {
            Text(range)
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 80, alignment: .leading)
            Text(desc)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func calculatePreview() {
        if room.surfaces.isEmpty {
            room.createDefaultSurfaces(
                floorMaterial: .woodFloor,
                ceilingMaterial: .plasterOnBrick,
                wallMaterial: .plasterOnBrick
            )
        }
        recentAnalysis = acousticsCalculator.analyzeRoom(room: room)
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(color.opacity(0.1))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview {
    ContentView()
}
