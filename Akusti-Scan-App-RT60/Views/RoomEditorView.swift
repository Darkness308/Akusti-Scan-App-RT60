//
//  RoomEditorView.swift
//  Akusti-Scan-App-RT60
//
//  Manual room dimension and material editor
//

import SwiftUI

struct RoomEditorView: View {
    @Binding var room: Room
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            // Room name
            Section("Raumname") {
                TextField("Name", text: $room.name)
            }

            // Dimensions
            Section("Abmessungen") {
                dimensionRow(label: "Länge", value: $room.length, unit: "m")
                dimensionRow(label: "Breite", value: $room.width, unit: "m")
                dimensionRow(label: "Höhe", value: $room.height, unit: "m")

                HStack {
                    Text("Volumen")
                    Spacer()
                    Text(String(format: "%.1f m³", room.volume))
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Oberfläche")
                    Spacer()
                    Text(String(format: "%.1f m²", room.totalSurfaceArea))
                        .foregroundStyle(.secondary)
                }
            }

            // Environment
            Section("Umgebung") {
                dimensionRow(label: "Temperatur", value: $room.temperature, unit: "°C")
                dimensionRow(label: "Luftfeuchtigkeit", value: $room.humidity, unit: "%")
            }

            // Surfaces
            Section("Oberflächen") {
                if room.surfaces.isEmpty {
                    Button("Standard-Oberflächen erstellen") {
                        createDefaultSurfaces()
                    }
                } else {
                    ForEach($room.surfaces) { $surface in
                        surfaceRow(surface: $surface)
                    }
                }
            }

            // Presets
            Section("Voreinstellungen") {
                Button("Wohnzimmer") { applyPreset(.livingRoom) }
                Button("Büro") { applyPreset(.office) }
                Button("Konferenzraum") { applyPreset(.conferenceRoom) }
                Button("Studio") { applyPreset(.studio) }
            }
        }
        .navigationTitle("Raum bearbeiten")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Components

    private func dimensionRow(label: String, value: Binding<Double>, unit: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("", value: value, format: .number.precision(.fractionLength(1)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 30)
        }
    }

    private func surfaceRow(surface: Binding<RoomSurface>) -> some View {
        NavigationLink {
            SurfaceEditorView(surface: surface)
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(surface.wrappedValue.name)
                    Text(surface.wrappedValue.material.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(String(format: "%.1f m²", surface.wrappedValue.area))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Actions

    private func createDefaultSurfaces() {
        room.createDefaultSurfaces(
            floorMaterial: .woodFloor,
            ceilingMaterial: .plasterOnBrick,
            wallMaterial: .plasterOnBrick
        )
    }

    private func applyPreset(_ preset: RoomPreset) {
        switch preset {
        case .livingRoom:
            room.width = 5.0
            room.length = 7.0
            room.height = 2.5
            room.name = "Wohnzimmer"
            room.createDefaultSurfaces(
                floorMaterial: .woodFloor,
                ceilingMaterial: .plasterOnBrick,
                wallMaterial: .plasterOnBrick
            )

        case .office:
            room.width = 4.0
            room.length = 5.0
            room.height = 2.8
            room.name = "Büro"
            room.createDefaultSurfaces(
                floorMaterial: .carpet,
                ceilingMaterial: .acousticTile,
                wallMaterial: .plasterOnBrick
            )

        case .conferenceRoom:
            room.width = 6.0
            room.length = 10.0
            room.height = 3.0
            room.name = "Konferenzraum"
            room.createDefaultSurfaces(
                floorMaterial: .carpet,
                ceilingMaterial: .acousticTile,
                wallMaterial: .glass
            )

        case .studio:
            room.width = 5.0
            room.length = 6.0
            room.height = 3.5
            room.name = "Studio"
            room.createDefaultSurfaces(
                floorMaterial: .woodFloor,
                ceilingMaterial: .acousticTile,
                wallMaterial: .curtains
            )
        }
    }
}

enum RoomPreset {
    case livingRoom, office, conferenceRoom, studio
}

// MARK: - Surface Editor

struct SurfaceEditorView: View {
    @Binding var surface: RoomSurface
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Bezeichnung") {
                TextField("Name", text: $surface.name)
            }

            Section("Fläche") {
                HStack {
                    Text("Fläche")
                    Spacer()
                    TextField("", value: $surface.area, format: .number.precision(.fractionLength(2)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("m²")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Material") {
                ForEach(AcousticMaterial.materials, id: \.id) { material in
                    Button {
                        surface.material = material
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(material.name)
                                    .foregroundStyle(.primary)

                                Text(absorptionSummary(material))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if surface.material.id == material.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }

            Section("Absorptionskoeffizienten") {
                ForEach(FrequencyBand.allCases, id: \.self) { band in
                    HStack {
                        Text(band.rawValue)
                        Spacer()
                        Text(String(format: "%.2f", surface.material.absorption(at: band)))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(surface.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func absorptionSummary(_ material: AcousticMaterial) -> String {
        let avg = FrequencyBand.allCases.reduce(0.0) { sum, band in
            sum + material.absorption(at: band)
        } / Double(FrequencyBand.allCases.count)

        return String(format: "Ø %.2f", avg)
    }
}
