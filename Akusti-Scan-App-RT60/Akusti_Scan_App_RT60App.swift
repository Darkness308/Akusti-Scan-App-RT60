//
//  Akusti_Scan_App_RT60App.swift
//  Akusti-Scan-App-RT60
//
//  Created by Marc Schneider-Handrup on 03.11.25.
//

import SwiftUI
import SwiftData

@main
struct Akusti_Scan_App_RT60App: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            MeasurementRecord.self,
            SavedRoom.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
