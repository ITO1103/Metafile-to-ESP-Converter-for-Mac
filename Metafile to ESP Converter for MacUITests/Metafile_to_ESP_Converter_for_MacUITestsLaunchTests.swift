//
//  Metafile_to_ESP_Converter_for_MacUITestsLaunchTests.swift
//  Metafile to ESP Converter for MacUITests
//
//  Created by 伊藤駿介 on 2025/07/17.
//

import XCTest

final class Metafile_to_ESP_Converter_for_MacUITestsLaunchTests: XCTestCase {

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
