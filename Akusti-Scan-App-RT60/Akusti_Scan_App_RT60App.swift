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

    let container = DependencyContainer.shared

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: RT60ViewModel(
                audioRecorder: container.audioRecorder,
                rt60Calculator: container.rt60Calculator
            ))
        }
        .modelContainer(sharedModelContainer)
    }
}
