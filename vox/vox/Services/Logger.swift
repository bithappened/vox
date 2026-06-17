import Foundation
import os.log

private let logger = Logger(subsystem: "so.kubo.vox", category: "app")

/// Lightweight debug-only log helper. Compiles out in release builds.
func debugLog(_ message: @autoclosure () -> String) {
  #if DEBUG
    let resolved = message()
    logger.debug("\(resolved, privacy: .public)")
  #endif
}
