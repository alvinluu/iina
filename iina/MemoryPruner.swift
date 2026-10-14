//
//  MemoryPruner.swift
//  iina
//
//  Reclaims memory held by IINA and the underlying mpv cores.
//  Copyright © 2026 lhc. All rights reserved.
//

import Foundation

/// Frees memory held by IINA and the underlying mpv cores.
///
/// Two entry points:
/// - ``pruneNow(full:reason:)`` — user initiated (the "Free Up Memory" menu command). Clears the
///   in-RAM caches of every player and, when `full`, forces each active mpv core to evict its
///   demuxer cache before letting it refill to the configured ceiling.
/// - An automatic watcher (``start()``) that, while `Preference.pruneMemoryAutomatically` is on,
///   samples the process footprint every ``checkInterval`` seconds. When it exceeds
///   `memoryPruneThresholdMB` the watcher clears the in-RAM caches once and *constrains* each mpv
///   core's cache ceiling so the footprint stays bounded without repeatedly flushing the cache
///   (which would thrash playback). The configured ceiling is restored once the footprint drops
///   comfortably back under the threshold (hysteresis).
class MemoryPruner {

  static let shared = MemoryPruner()

  /// One mebibyte in bytes. The user-facing threshold is expressed in these units ("1 GB" = 1024).
  private static let mib = 1024 * 1024

  /// How often the automatic watcher samples the footprint.
  private let checkInterval: TimeInterval = 12

  /// mpv cache ceiling applied to each active core while memory constrained.
  private let constrainedMaxBytes = "48MiB"
  private let constrainedMaxBackBytes = "16MiB"
  private let constrainedCacheSecs = "60"

  /// Release constraints once the footprint falls below `threshold * releaseFactor`. The gap avoids
  /// flapping between the constrained and configured ceilings around the threshold.
  private let releaseFactor = 0.8

  private var timer: Timer?

  /// `true` while the automatic watcher is holding the mpv cores at the constrained ceiling.
  private var constrained = false

  private init() {}

  // MARK: - Automatic watcher

  /// Starts the automatic footprint watcher. Safe to call more than once; only the first call has
  /// an effect.
  func start() {
    guard timer == nil else { return }
    let timer = Timer(timeInterval: checkInterval, repeats: true) { [weak self] _ in
      self?.checkFootprint()
    }
    // `.common` so the watcher keeps firing while a menu or other modal run loop is up.
    RunLoop.main.add(timer, forMode: .common)
    self.timer = timer
    log("Automatic memory pruning watcher started (interval \(Int(checkInterval))s)")
  }

  private func checkFootprint() {
    guard Preference.bool(for: .pruneMemoryAutomatically) else {
      // Feature was turned off while constrained: give the cores their configured cache back.
      if constrained { releaseCacheConstraints() }
      return
    }
    guard let footprint = MemoryUsage.shared.footprintBytes else { return }
    let thresholdMB = Preference.integer(for: .memoryPruneThresholdMB)
    guard thresholdMB > 0 else { return }
    let threshold = thresholdMB * Self.mib

    if footprint > threshold {
      // Prune and constrain only on the transition into the over-threshold state. While we stay
      // over, the constrained ceiling already bounds mpv, so we avoid repeatedly flushing.
      guard !constrained else { return }
      log("Footprint \(footprint / Self.mib)MiB exceeded cap \(thresholdMB)MiB; pruning and constraining caches",
          level: .warning)
      pruneInRAMCaches()
      applyCacheConstraints()
    } else if constrained && footprint < Int(Double(threshold) * releaseFactor) {
      releaseCacheConstraints()
    }
  }

  // MARK: - Manual prune

  /// Frees memory now.
  /// - Parameters:
  ///   - full: When `true`, also forces each active mpv core to evict its demuxer cache. When
  ///     `false`, only the in-RAM IINA caches are cleared.
  ///   - reason: Short tag included in the before/after memory log lines.
  func pruneNow(full: Bool, reason: String = "manual") {
    MemoryUsage.shared.logUsage("before prune (\(reason))")
    pruneInRAMCaches()
    if full {
      flushMpvCaches()
    }
    // mpv evicts asynchronously on its own thread; log the result once it has had a moment.
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
      MemoryUsage.shared.logUsage("after prune (\(reason))")
    }
  }

  // MARK: - Helpers

  /// Clears the in-RAM caches (thumbnails and transient lookup dictionaries) of every player. All
  /// of these are rebuilt lazily, so this is always safe and never touches the mpv core.
  private func pruneInRAMCaches() {
    for pc in PlayerCore.playerCores {
      pc.info.thumbnails = []
      pc.info.thumbnailsReady = false
      pc.info.clearTransientCaches()
    }
  }

  /// Forces every active mpv core to evict its demuxer cache now, then restores a sensible ceiling
  /// (the constrained ceiling if the watcher currently holds one, otherwise the configured size) so
  /// the cache refills normally.
  private func flushMpvCaches() {
    for pc in PlayerCore.playerCores where pc.info.state.active {
      pc.mpv.setString(MPVOption.Demuxer.demuxerMaxBytes, "24MiB")
      pc.mpv.setString(MPVOption.Demuxer.demuxerMaxBackBytes, "8MiB")
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
      guard let self else { return }
      if self.constrained {
        self.applyCacheConstraints()
      } else {
        self.restoreConfiguredCacheCeilings()
      }
    }
  }

  private func applyCacheConstraints() {
    constrained = true
    for pc in PlayerCore.playerCores where pc.info.state.active {
      pc.mpv.setString(MPVOption.Demuxer.demuxerMaxBytes, constrainedMaxBytes)
      pc.mpv.setString(MPVOption.Demuxer.demuxerMaxBackBytes, constrainedMaxBackBytes)
      pc.mpv.setString(MPVOption.Cache.cacheSecs, constrainedCacheSecs)
    }
  }

  private func releaseCacheConstraints() {
    constrained = false
    restoreConfiguredCacheCeilings()
    log("Footprint back under cap; restored configured mpv cache ceilings")
  }

  private func restoreConfiguredCacheCeilings() {
    let maxBytesKiB = Preference.integer(for: .defaultCacheSize)
    let cacheSecs = Preference.integer(for: .secPrefech)
    for pc in PlayerCore.playerCores where pc.info.state.active {
      pc.mpv.setString(MPVOption.Demuxer.demuxerMaxBytes, "\(maxBytesKiB)KiB")
      pc.mpv.setStringToDefault(MPVOption.Demuxer.demuxerMaxBackBytes)
      pc.mpv.setString(MPVOption.Cache.cacheSecs, "\(cacheSecs)")
    }
  }

  private func log(_ message: @autoclosure () -> String, level: Logger.Level = .debug) {
    Logger.log(message(), level: level, subsystem: Logger.Sub.memory)
  }
}
