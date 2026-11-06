//
//  OSCToolbarButton.swift
//  iina
//
//  Created by Matt Svoboda on 11/6/22.
//  Copyright © 2022 lhc. All rights reserved.
//

import Foundation

// Not elegant. Just a place to stick common code so that it won't be duplicated
class OSCToolbarButton {
  
  /// - Parameters:
  ///   - reducedWidth: For the current OSC design, the width need to be compressed when there are five buttons in the floating OSC
  static func setStyle(of toolbarButton: NSButton, buttonType: Preference.ToolBarButton, reducedWidth: Bool = false) {
    toolbarButton.translatesAutoresizingMaskIntoConstraints = false
    toolbarButton.bezelStyle = .regularSquare
    toolbarButton.image = buttonType.image()
    toolbarButton.isBordered = false
    toolbarButton.tag = buttonType.rawValue
    toolbarButton.refusesFirstResponder = true
    toolbarButton.toolTip = buttonType.localizedDescription()
    let buttonHeight = Preference.ToolBarButton.frameSize
    let buttonWidth = reducedWidth ? Preference.ToolBarButton.compactFrameWidth : Preference.ToolBarButton.frameSize
    toolbarButton.size(width: buttonWidth, height: buttonHeight)
  }

  static func buildDragItem(from toolbarButton: NSButton, pasteboardWriter: NSPasteboardWriting,
                            buttonType: Preference.ToolBarButton) -> NSDraggingItem? {
    // seems to be the only reliable way to get image size
    guard let imageSize = toolbarButton.image?.representations[at: 0]?.size else { return nil }

    let dragItem = NSDraggingItem(pasteboardWriter: pasteboardWriter)
    let iconSize = Preference.ToolBarButton.frameSize
    // Image is centered in frame, and frame has 0px offset from left & bottom of superview
    let dragOrigin = CGPoint(x: (iconSize - imageSize.width) / 2, y: (iconSize - imageSize.height) / 2)
    dragItem.draggingFrame = NSRect(origin: dragOrigin, size: imageSize)
    Logger.log("Dragging from AvailableItemsView: \(dragItem.draggingFrame) (imageSize: \(imageSize))")
    dragItem.imageComponentsProvider = {
      let imageComponent = NSDraggingImageComponent(key: .icon)
      let image = buttonType.image().tinted(.textColor)
      imageComponent.contents = image
      imageComponent.frame = NSRect(origin: .zero, size: imageSize)
      return [imageComponent]
    }

    return dragItem
  }
}

/// A toolbar button for an on/off setting. Draws an underline below the icon: accent-colored when on, faint when off.
class OSCToggleToolbarButton: NSButton {
  var isOn = false {
    didSet {
      guard isOn != oldValue else { return }
      needsDisplay = true
    }
  }

  private static let underlineWidth: CGFloat = 14
  private static let underlineHeight: CGFloat = 2.5
  /// Extra room below the 24pt toolbar row for the underline, so it sits clear of the glyph.
  private static let underlineSpace: CGFloat = 3
  /// A saturated bright blue that stands out on the dark OSC.
  static let onColor = NSColor(srgbRed: 0.16, green: 0.6, blue: 1, alpha: 1)
  private var loggedFrame: NSRect?

  // Auto Layout places a button by its alignment rect. Keep that rect at the 24pt toolbar frame like the
  // other buttons (with no image-dependent insets), and extend the real frame below it for the underline.
  override var alignmentRectInsets: NSEdgeInsets {
    NSEdgeInsets(top: 0, left: 0, bottom: OSCToggleToolbarButton.underlineSpace, right: 0)
  }

  override func layout() {
    super.layout()
    if loggedFrame != frame {
      loggedFrame = frame
      Logger.log("OSC toggle \(Preference.ToolBarButton(rawValue: tag)?.description ?? "\(tag)") frame: \(frame)")
    }
  }

  override func draw(_ dirtyRect: NSRect) {
    let space = OSCToggleToolbarButton.underlineSpace
    let w = OSCToggleToolbarButton.underlineWidth, h = OSCToggleToolbarButton.underlineHeight
    // Draw the glyph in the 24pt area so it lines up with the other toolbar buttons.
    var glyphRect = bounds
    glyphRect.size.height -= space
    if !isFlipped { glyphRect.origin.y += space }
    cell?.draw(withFrame: glyphRect, in: self)
    // The underline straddles the bottom of the glyph area, about 3.5pt below the glyph.
    let y = isFlipped ? glyphRect.maxY - 1 : glyphRect.minY + 1 - h
    let rect = NSRect(x: bounds.midX - w / 2, y: y, width: w, height: h)
    (isOn ? OSCToggleToolbarButton.onColor : NSColor.labelColor.withAlphaComponent(0.25)).setFill()
    NSBezierPath(roundedRect: rect, xRadius: h / 2, yRadius: h / 2).fill()
  }
}
