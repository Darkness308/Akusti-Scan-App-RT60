//
//  Akusti_Scan_App_RT60UITestsLaunchTests.swift
//  Akusti-Scan-App-RT60UITests
//
//  Created by Marc Schneider-Handrup on 03.11.25.
//

import XCTest

final class Akusti_Scan_App_RT60UITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
