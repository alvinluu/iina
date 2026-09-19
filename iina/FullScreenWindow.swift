//
//  FullScreenWindow.swift
//  iina
//

import Cocoa

/// A disposable window used only for the opt-in "detached full screen" mode
/// (`Preference.Key.useDetachedFullScreen`). Created fresh each time detached full screen is
/// entered, and discarded on exit, so the main window's own AppKit-private per-window state --
/// which gets stuck after a normal full-screen transition, native or legacy; see the KNOWN ISSUE
/// note above `setWindowScale` in MainWindowController.swift -- is never touched by going through
/// a full-screen cycle at all.
///
/// Subclasses `MainWindow` to inherit its `forceKeyAndMain` (required for a borderless window to
/// become key/main) and its keyDown/performKeyEquivalent forwarding to the window controller.
class FullScreenWindow: MainWindow {
  convenience init(screen: NSScreen) {
    self.init(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false,
              screen: screen)
    forceKeyAndMain = true
    isReleasedWhenClosed = false
    level = .floating
    hasShadow = false
    collectionBehavior = [.fullScreenAuxiliary]
    isOpaque = true
    backgroundColor = .black
    contentView = MainWindowContentView(frame: NSRect(origin: .zero, size: screen.frame.size))
  }
}
