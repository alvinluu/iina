//
//  TranslucentView.swift
//  iina
//
//  Created by Hechen Li on 2026-05-27.
//  Copyright © 2026 lhc. All rights reserved.
//

class TranslucentView: NSView {
  enum Style {
    case liquidGlass
    case visualEffect
  }

  private var liquidGlassCornerRadius: CGFloat
  private var vevCornerRadius: CGFloat
  private var padding: (CGFloat, CGFloat)
  var content: NSView?
  var container: NSView?
  var style: Style
  private var appliedStyle: Style?

  init(liquidGlassCornerRadius: CGFloat = 16, vevCornerRadius: CGFloat = 8, padding: (CGFloat, CGFloat)) {
    self.liquidGlassCornerRadius = liquidGlassCornerRadius
    self.vevCornerRadius = vevCornerRadius
    self.padding = padding
    self.style = if #available(macOS 26, *) {
      .liquidGlass
    } else {
      .visualEffect
    }
    super.init(frame: .zero)

    self.translatesAutoresizingMaskIntoConstraints = false
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidMoveToWindow() {
    if let vev = container as? NSVisualEffectView {
      vev.state = .active
    }
  }

  func setContent(_ content: NSView) {
    self.content = content
    content.translatesAutoresizingMaskIntoConstraints = false
    setStyle(style, force: true)
  }

  func setStyle(_ newStyle: Style, force: Bool = false) {
    self.style = newStyle
    let force = force || (appliedStyle != newStyle)
    guard let content, force else { return }

    let wrapper = NSView()
    wrapper.translatesAutoresizingMaskIntoConstraints = false

    // [    [         [--padding--[      ]]]]
    // self container wrapper     content
    //
    // We can't control the padding between the container (Glass/VE View)
    // and its content, so we need the wrapper

    wrapper.addSubview(content)
    addContentPadding()

    switch newStyle {
    case .liquidGlass:
      if #available(macOS 26.0, *) {
        let view = NSGlassEffectView()
        view.cornerRadius = liquidGlassCornerRadius
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentView = wrapper
        container = view
      } else {
        fatalError()
      }
    case .visualEffect:
      let view = NSVisualEffectView()
      view.clipsToBounds = true
      view.translatesAutoresizingMaskIntoConstraints = false
      view.blendingMode = .withinWindow
      view.material = .popover
      view.addSubview(wrapper)
      wrapper.padding(.all)
      view.wantsLayer = true
      view.layer?.cornerRadius = vevCornerRadius
      container = view
    }

    subviews.forEach { $0.removeFromSuperview() }
    addSubview(container!)
    container!.padding(.all)

    appliedStyle = style
  }

  func addContentPadding() {
    content!.padding(.horizontal(padding.0), .vertical(padding.1))
  }

  /// Works around an intermittent macOS 26 bug where AppKit state (frames, alpha, images) is
  /// completely correct but the on-screen contents of an `NSGlassEffectView`'s contentView stop
  /// being composited -- observed with the floating OSC's toolbar buttons after loading a new
  /// video. Marking the child views (or this outer view) as needing display does not reliably
  /// recover it; re-asserting `contentView` on the glass view itself forces its content layers to
  /// be rebuilt and does.
  func forceContentRefresh() {
    guard let container else {
      needsDisplay = true
      return
    }
    container.needsLayout = true
    container.needsDisplay = true
    if #available(macOS 26.0, *), let glass = container as? NSGlassEffectView {
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      let wrapper = glass.contentView
      glass.contentView = nil
      glass.contentView = wrapper
      CATransaction.commit()
    }
  }

  func setCornerRadius(liquidGlass: CGFloat, vev: CGFloat) {
    liquidGlassCornerRadius = liquidGlass
    vevCornerRadius = vev
    switch appliedStyle {
    case .liquidGlass:
      if #available(macOS 26.0, *) {
        let view = container as! NSGlassEffectView
        view.cornerRadius = liquidGlassCornerRadius
      } else {
        fatalError()
      }
    case .visualEffect:
      let view = container as! NSVisualEffectView
      view.layer?.cornerRadius = vevCornerRadius
    default:
      break
    }
  }

  override func rightMouseDown(with event: NSEvent) {}
  override func rightMouseUp(with event: NSEvent) {}
}
