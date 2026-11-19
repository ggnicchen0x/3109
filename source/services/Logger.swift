// Logger.swift — Centralized logging
// Reconstructed from 5013 v3.2.17 binary

import Foundation
import os.log

private let subsystem = "_013"
private let logger = Logger(subsystem: subsystem, category: "App")

func log(_ message: String, file: String = #file, line: UInt = #line, function: String = #function) {
    let filename = (file as NSString).lastPathComponent
    logger.info("[\(filename):\(line)] \(function): \(message)")
}

private var logCaptureSetup = false

func setupLogCapture() {
    guard !logCaptureSetup else { return }
    logCaptureSetup = true
}
