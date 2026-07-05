//
//  MainWindowMenuActions.swift
//  iina
//
//  Created by lhc on 13/8/2017.
//  Copyright © 2017 lhc. All rights reserved.
//

import Cocoa

extension MainWindowController {

  @objc func menuShowPlaylistPanel(_ sender: NSMenuItem) {
    sidebars.show(tab: "playlist")
  }

  @objc func menuShowChaptersPanel(_ sender: NSMenuItem) {
    sidebars.show(tab: "chapters")
  }

  @objc func menuShowVideoQuickSettings(_ sender: NSMenuItem) {
    sidebars.show(tab: "video")
  }

  @objc func menuShowAudioQuickSettings(_ sender: NSMenuItem) {
    sidebars.show(tab: "audio")
  }

  @objc func menuShowSubQuickSettings(_ sender: NSMenuItem) {
    sidebars.show(tab: "sub")
  }

  @objc func menuChangeWindowSize(_ sender: NSMenuItem) {
    //  0: half
    //  2: double
    //  3: fit screen
    //  4: 70%
    //  5: normal
    //  6: 130%
    //  7: 170%
    //  10: smaller size
    //  11: bigger size
    let size = sender.tag
    guard let window = window, !fsState.isFullscreen else { return }

    let screenFrame = (window.screen ?? NSScreen.main!).visibleFrame
    let newFrame: NSRect
    let sizeMap: [Int: Double] = [0: 0.5, 2: 2, 4: 0.7, 5: 1, 6: 1.3, 7: 1.7]
    let scaleStep: CGFloat = 25

    switch size {
    // scale
    case 0, 2, 4, 5, 6, 7:
      guard let scale = sizeMap[size] else { return }
      setWindowScale(scale)
      return
    // fit screen
    case 3:
      window.center()
      newFrame = window.frame.centeredResize(to: window.frame.size.shrink(toSize: screenFrame.size))
    // bigger size
    case 10, 11:
      let newWidth = window.frame.width + scaleStep * (size == 10 ? -1 : 1)
      let newHeight = newWidth / (window.aspectRatio.width / window.aspectRatio.height)
      newFrame = window.frame.anchoredResize(to: NSSize(width: newWidth, height: newHeight).satisfyMinSizeWithSameAspectRatio(AppData.mainWindowMinSize), screenFrame: screenFrame)
    default:
      return
    }

    window.setFrame(newFrame, display: true, animate: true)
    updateWindowParametersForMPV(withFrame: newFrame)
  }

  @objc func menuAlwaysOnTop(_ sender: AnyObject) {
    setWindowFloatingOnTop(!isOntop)
  }

  @objc func menuLockAspectRatio(_ sender: NSMenuItem) {
    let unlock = Preference.bool(for: .unlockWindowAspectRatio)
    Preference.set(!unlock, for: .unlockWindowAspectRatio)
  }

  @objc func menuTogglePIP(_ sender: NSMenuItem) {
    switch pipStatus {
    case .notInPIP:
      enterPIP()
    case .inPIP:
      exitPIP()
    default:
      return
    }
  }

  @objc func menuToggleFullScreen(_ sender: NSMenuItem) {
    toggleWindowFullScreen()
  }

  @objc func menuSwitchToMiniPlayer(_ sender: NSMenuItem) {
    player.switchToMiniPlayer()
  }

  @objc func menuSetDelogo(_ sender: NSMenuItem) {
    if sender.state == .on {
      if let filter = player.info.delogoFilter {
        let _ = player.removeVideoFilter(filter)
        player.info.delogoFilter = nil
      }
    } else {
      self.sidebars.hideAllSideBars {
        self.interactiveMode.enter(mode: .delogo)
      }
    }
  }
}
