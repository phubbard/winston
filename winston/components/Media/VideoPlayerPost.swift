import SwiftUI
import Defaults
import CoreMedia
import AVKit
import AVFoundation
import Combine

/// Owns ONE AVPlayer for the lifetime of a single VideoPlayerPost view. Held via @StateObject, so its
/// `deinit` fires reliably when SwiftUI destroys the cell (de-realizes it from the List) — unlike
/// `onDisappear`, which a List fires unreliably. This is the fix for the real bug: previously each
/// SharedVideo stored its own AVPlayer and PostWinstonData's append-only feed-entity list pinned it
/// alive forever, so players NEVER deallocated (52 after one feed load, climbing for the whole
/// session) until iOS silently stopped letting new players start and videos froze until a restart.
/// Tying the player to the view's lifetime caps the live count to the List's realization window and
/// guarantees teardown.
final class VideoPlayerHolder: ObservableObject {
  let player: AVPlayer?
  init(url: URL?) {
    if let url = url {
      let p = AVPlayer(playerItem: AVPlayerItem(url: url))
      p.volume = 0.0
      player = p
    } else {
      player = nil
    }
  }
  deinit {
    player?.pause()
    player?.replaceCurrentItem(with: nil)
  }
}

struct SharedVideo: Equatable {
  static func == (lhs: SharedVideo, rhs: SharedVideo) -> Bool {
    lhs.url == rhs.url && lhs.size == rhs.size
  }

  var url: URL
  var size: CGSize

  static func get(url: URL, size: CGSize, resetCache: Bool = false) -> SharedVideo {
    return SharedVideo(url: url, size: size)
  }

  static func cacheKey(url: URL, size: CGSize) -> String {
    return "\(url.absoluteString):\(size.width)x\(size.height)"
  }

  init(url: URL, size: CGSize) {
    self.url = url
    self.size = size
  }
}

/// Holds block-based NotificationCenter tokens for a video and removes them on teardown.
/// Block observers can ONLY be removed with the token returned at registration, and this
/// bag's deinit guarantees removal even if SwiftUI recycles a cell without calling onDisappear.
final class VideoObserverBag {
  private var tokens: [NSObjectProtocol] = []
  func set(_ newTokens: [NSObjectProtocol]) {
    removeAll()
    tokens = newTokens
  }
  func removeAll() {
    tokens.forEach { NotificationCenter.default.removeObserver($0) }
    tokens = []
  }
  deinit { removeAll() }
}

struct VideoPlayerPost: View, Equatable {
  static func == (lhs: VideoPlayerPost, rhs: VideoPlayerPost) -> Bool {
    lhs.url == rhs.url && lhs.sharedVideo == rhs.sharedVideo
  }
  
  weak var controller: UIViewController?
  var sharedVideo: SharedVideo?
  let markAsSeen: (() async -> ())?
  var compact = false
  var contentWidth: CGFloat
  var url: URL
  var size: CGSize
  let resetVideo: ((SharedVideo) -> ())?
  var maxMediaHeightScreenPercentage: CGFloat
  @State private var firstFullscreen = false
  @State private var fullscreen = false
  @Default(.VideoDefSettings) private var videoDefSettings
  @Environment(\.scenePhase) private var scenePhase
  @State private var observerBag = VideoObserverBag()
  @State private var isVisible = false
  @StateObject private var holder: VideoPlayerHolder

  private var autoPlayVideos: Bool { videoDefSettings.autoPlay }
  private var loopVideos: Bool { videoDefSettings.loop }
  private var muteVideos: Bool { videoDefSettings.mute }
  private var pauseBackgroundAudioOnFullscreen: Bool { videoDefSettings.pauseBGAudioOnFullscreen }
  
  init(controller: UIViewController?, cachedVideo: SharedVideo?, markAsSeen: (() async -> ())?, compact: Bool = false, contentWidth: CGFloat, url: URL, resetVideo: ((SharedVideo) -> ())?, maxMediaHeightScreenPercentage: CGFloat) {
    self.controller = controller
    self.sharedVideo = cachedVideo
    self.markAsSeen = markAsSeen
    self.compact = compact
    self.contentWidth = contentWidth
    self.url = url
    self.size = cachedVideo?.size ?? .zero
    self.resetVideo = resetVideo
    self.maxMediaHeightScreenPercentage = maxMediaHeightScreenPercentage
    _holder = StateObject(wrappedValue: VideoPlayerHolder(url: cachedVideo != nil ? url : nil))
  }
  
  var safe: Double { getSafeArea().top + getSafeArea().bottom }
  
  
  var body: some View {
    let maxHeight: CGFloat = (maxMediaHeightScreenPercentage / 100) * (.screenH)
    let sourceWidth = size.width
    let sourceHeight = size.height
    let propHeight = (contentWidth * sourceHeight) / sourceWidth
    let finalHeight = maxMediaHeightScreenPercentage != 110 ? Double(min(maxHeight, propHeight)) : Double(propHeight)
    
    if let sharedVideo = sharedVideo, let player = holder.player {
			// (player comes from the per-view holder, bound in the if-let above)
      if let controller = controller {
        AVPlayerRepresentable(fullscreen: $fullscreen, autoPlayVideos: autoPlayVideos, player: player, aspect: .resizeAspectFill, controller: controller)
          .frame(width: compact ? scaledCompactModeThumbSize() : contentWidth, height: compact ? scaledCompactModeThumbSize() : CGFloat(finalHeight))
          .mask(RR(12, Color.black))
          .allowsHitTesting(false)
          .contentShape(Rectangle())
          .onTapGesture {
            if markAsSeen != nil { Task(priority: .background) { await markAsSeen?() } }
            withAnimation {
              fullscreen = true
            }
          }
      } else {
        ZStack {
          
          Group {
            // Only attach a player layer (= a decode pipeline) when this cell is actually
            // on-screen and not in fullscreen. Off-screen cells render Color.clear, which
            // tears the layer down via InlinePlayerLayer.dismantleUIView and frees the pipeline.
            if isVisible && !fullscreen {
              InlinePlayerLayer(player: player)
            } else {
              Color.clear
            }
          }
          .frame(width: compact ? scaledCompactModeThumbSize() : contentWidth, height: compact ? scaledCompactModeThumbSize() : CGFloat(finalHeight))
          .clipped()
          .fixedSize()
          .mask(RR(12, Color.black))
          .allowsHitTesting(false)
          .contentShape(Rectangle())
          .highPriorityGesture(TapGesture().onEnded({ _ in
            if markAsSeen != nil { Task(priority: .background) { await markAsSeen?() } }
            withAnimation {
              fullscreen = true
            }
          }))
          .allowsHitTesting(false)
          .mask(RR(12, Color.black))
          .overlay(
            Color.clear
              .contentShape(Rectangle())
              .onTapGesture {
                if markAsSeen != nil { Task(priority: .background) { await markAsSeen?() } }
                withAnimation {
                  fullscreen = true
                }
              }
          )
          
          Image(systemName: "play.fill").foregroundColor(.white.opacity(0.75)).fontSize(32).shadow(color: .black.opacity(0.45), radius: 12, y: 8).opacity(autoPlayVideos ? 0 : 1).allowsHitTesting(false)
        }
        .onAppear {
          isVisible = true
          if loopVideos {
            addObserver(player)
          }
          
          if (player.status == .failed) {
            resetVideo?(sharedVideo)
          }

          if autoPlayVideos {
            player.play()
          }
        }
        .onChange(of: scenePhase) { _, newPhase in
          if newPhase == .active {
            if (player.status == .failed) {
              resetVideo?(sharedVideo)
            }

            if autoPlayVideos {
              player.play()
            }
          }
        }
        .onDisappear() {
            isVisible = false
            removeObserver()
          Task(priority: .background) {
//            setAudioToMixWithOthers(false)
            player.seek(to: .zero)
            player.pause()
          }
        }
        .onChange(of: fullscreen) { _, val in
          if !firstFullscreen {
            firstFullscreen = true
						player.isMuted = muteVideos
            player.play()
          }
					if !val && !autoPlayVideos {
						player.seek(to: .zero)
						player.pause()
						firstFullscreen = false
					 }
          
//          if pauseBackgroundAudioOnFullscreen {
//            Task(priority: .background) {
//              setAudioToMixWithOthers(val)
//            }
//          }
          
          player.volume = val ? 1.0 : 0.0
        }
        .fullScreenCover(isPresented: $fullscreen) {
          FullScreenVP(player: player, size: sharedVideo.size)
        }
      }
    }
  }
  
  func addObserver(_ player: AVPlayer) {
    guard let sharedVideo = sharedVideo else { return }
    let center = NotificationCenter.default
    let item = player.currentItem
    let reset = resetVideo
    // Store the tokens so they can actually be removed; the bag's deinit is the safety net.
    observerBag.set([
      center.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: nil) { _ in
        Task(priority: .background) {
          player.seek(to: .zero)
          player.play()
        }
      },
      center.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: nil) { _ in
        Task { @MainActor in
          reset?(sharedVideo)
        }
      },
      center.addObserver(forName: .AVPlayerItemPlaybackStalled, object: item, queue: nil) { _ in
        Task { @MainActor in
          reset?(sharedVideo)
        }
      },
    ])
  }

  func removeObserver() {
    observerBag.removeAll()
  }
}

/// A bare AVPlayerLayer-backed view for inline (non-fullscreen) feed/detail video.
/// SwiftUI's `VideoPlayer` gave no teardown hook, so its decode pipeline (one per AVPlayerLayer)
/// leaked for every realized cell until iOS's ~16-pipeline limit was hit. This owns the layer
/// explicitly and releases it in `dismantleUIView`; combined with the `isVisible` gate in
/// VideoPlayerPost, the number of live decode pipelines stays near the on-screen video count.
/// The shared cached AVPlayer is left intact for instant resume.
final class PlayerLayerHostView: UIView {
  override class var layerClass: AnyClass { AVPlayerLayer.self }
  var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

struct InlinePlayerLayer: UIViewRepresentable {
  let player: AVPlayer
  var gravity: AVLayerVideoGravity = .resizeAspectFill


  func makeUIView(context: Context) -> PlayerLayerHostView {
    let view = PlayerLayerHostView()
    view.playerLayer.player = player
    view.playerLayer.videoGravity = gravity
    return view
  }

  func updateUIView(_ view: PlayerLayerHostView, context: Context) {
    if view.playerLayer.player !== player { view.playerLayer.player = player }
    view.playerLayer.videoGravity = gravity
  }

  static func dismantleUIView(_ view: PlayerLayerHostView, coordinator: ()) {
    view.playerLayer.player = nil
  }
}

struct FullScreenVP: View {
  var player: AVPlayer
  var size: CGSize
  @Environment(\.dismiss) private var dismiss
  @State private var cancelDrag: Bool?
  @State private var isPinching: Bool = false
  @State private var drag: CGSize = .zero
  @State private var scale: CGFloat = 1.0
  @State private var anchor: UnitPoint = .zero
  @State private var offset: CGSize = .zero
  @State private var altSize: CGSize = .zero
  var body: some View {
    let interpolate = interpolatorBuilder([0, 100], value: abs(drag.height))
    VideoPlayer(player: player)
      .background(
        size != .zero
        ? nil
        : GeometryReader { geo in
          Color.clear
            .onAppear { altSize = geo.size }
            .onChange(of: geo.size) { _, newValue in altSize = newValue }
        }
      )
    //      .pinchToZoom(size: sharedVideo.size == .zero ? altSize : sharedVideo.size, isPinching: $isPinching, scale: $scale, anchor: $anchor, offset: $offset)
      .scaleEffect(interpolate([1, 0.9], true))
      .offset(cancelDrag ?? false ? .zero : drag)
      .gesture(
        scale != 1.0
        ? nil
        : DragGesture(minimumDistance: 10)
          .onChanged { val in
            if cancelDrag == nil { cancelDrag = abs(val.translation.width) > abs(val.translation.height) }
            if cancelDrag == nil || cancelDrag! { return }
            var transaction = Transaction()
            transaction.isContinuous = true
            transaction.animation = .interpolatingSpring(stiffness: 1000, damping: 100, initialVelocity: 0)
            
            let endPos = val.translation
            withTransaction(transaction) {
              drag = endPos
            }
          }
          .onEnded { val in
            let prevCancelDrag = cancelDrag
            cancelDrag = nil
            if prevCancelDrag == nil || prevCancelDrag! { return }
            let shouldClose = abs(val.translation.width) > 100 || abs(val.translation.height) > 100
            withAnimation(.interpolatingSpring(stiffness: 200, damping: 20, initialVelocity: 0)) {
              drag = .zero
              if shouldClose {
                dismiss()
              }
            }
          }
      )
  }
}

struct AVPlayerRepresentable: UIViewRepresentable {
  @Binding var fullscreen: Bool
  var autoPlayVideos: Bool
  let player: AVPlayer
  let aspect: AVLayerVideoGravity
  var controller: UIViewController

  func makeUIView(context: Context) -> UIView {
    let view = UIView()
    let playerController = NiceAVPlayer(fullscreen: $fullscreen, autoPlayVideos: autoPlayVideos)
    playerController.allowsVideoFrameAnalysis = false
    playerController.player = player
    playerController.videoGravity = aspect

    context.coordinator.controller = playerController
    controller.addChild(playerController)
    playerController.view.frame = view.bounds
    view.addSubview(playerController.view)
    playerController.didMove(toParent: controller)
    view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    return view
  }

  func updateUIView(_ view: UIView, context: Context) {
    if let playerController = context.coordinator.controller, playerController.autoPlayVideos != autoPlayVideos {
      playerController.autoPlayVideos = autoPlayVideos
    }
    if fullscreen {
      context.coordinator.controller?.enterFullScreen(animated: true)
    }
  }

  // Without this, every video cell scrolled past leaks its AVPlayerViewController:
  // `makeUIView` calls `controller.addChild(...)` but nothing ever calls
  // `removeFromParent()`, so the child VC (and its AVPlayerLayer / decode session)
  // stays alive on the long-lived feed controller. iOS only allows ~16 simultaneous
  // video pipelines, so after scrolling past enough videos new ones can't render
  // (no autoplay in the list, a frame or two then a stall in the post). Detaching
  // here releases the layer's decode session while leaving the shared cached
  // AVPlayer intact for reuse.
  static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
    if let playerController = coordinator.controller {
      playerController.willMove(toParent: nil)
      playerController.view.removeFromSuperview()
      playerController.removeFromParent()
      playerController.player = nil
    }
    coordinator.controller = nil
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  class Coordinator: NSObject {
    var controller: NiceAVPlayer? = nil
  }
}

class NiceAVPlayer: AVPlayerViewController, AVPlayerViewControllerDelegate {
  @Binding var fullscreen: Bool
  var autoPlayVideos: Bool
  var ida = UUID().uuidString
  var gone = true
  private var loopObserver: NSObjectProtocol?
  @Default(.VideoDefSettings) private var videoDefSettings
  override open var prefersStatusBarHidden: Bool {
    return true
  }

  init(fullscreen: Binding<Bool>, autoPlayVideos: Bool) {
    self._fullscreen = fullscreen
    self.autoPlayVideos = autoPlayVideos
    super.init(nibName: nil, bundle: nil)
    self.delegate = self
    showsPlaybackControls = false
  }

  required init?(coder aDecoder: NSCoder) {
    self.autoPlayVideos = false
    self._fullscreen = Binding(get: { true }, set: { _, _ in return })
    super.init(coder: aDecoder)
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if videoDefSettings.loop, let player = self.player, loopObserver == nil {
      loopObserver = NotificationCenter.default.addObserver(
        forName: .AVPlayerItemDidPlayToEndTime,
        object: player.currentItem,
        queue: nil) { [weak self] _ in
          guard self != nil else { return }
          player.seek(to: .zero)
          player.play()
        }
    }
    if autoPlayVideos && gone {
      self.player?.play()
      gone = false
    }
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    // Block observers need the token to be removed; removeObserver(self,…) removed nothing.
    if let token = loopObserver {
      NotificationCenter.default.removeObserver(token)
      loopObserver = nil
    }
    if !showsPlaybackControls {
      player?.pause()
      gone = true
    }
  }

  deinit {
    if let token = loopObserver { NotificationCenter.default.removeObserver(token) }
  }

  @objc private func didTapView() {
    enterFullScreen(animated: true)
    showsPlaybackControls = true
  }

  func enterFullScreen(animated: Bool) {
    let selector = NSSelectorFromString("enterFullScreenAnimated:completionHandler:")
    
    if self.responds(to: selector) {
      self.perform(selector, with: animated, with: nil)
    }
  }

  func exitFullScreen(animated: Bool) {
    let selector = NSSelectorFromString("exitFullScreenAnimated:completionHandler:")
    
    if self.responds(to: selector) {
      self.perform(selector, with: animated, with: nil)
    }
  }

  func playerViewController(
    _ playerViewController: AVPlayerViewController,
    willBeginFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator
  ) {
    coordinator.animate(alongsideTransition: nil) { [weak self] context in
      guard let self = self else { return }
      if context.isCancelled {
        // Still embedded inline
      } else {
        // Presented full screen
        // Take strong reference to playerViewController if needed
        self.player?.volume = 1.0
        self.player?.play()
        self.showsPlaybackControls = true
      }
    }
  }

  func playerViewController(
    _ playerViewController: AVPlayerViewController,
    willEndFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator
  ) {
    let isPlaying = self.player?.isPlaying ?? false
    coordinator.animate(alongsideTransition: nil) { [weak self] context in
      guard let self = self else { return }
      if context.isCancelled {
        // Still full screen
      } else {
        // Embedded inline
        // Remove strong reference to playerViewController if held
        self.fullscreen = false
        doThisAfter(0.0) {
          self.player?.volume = 0.0
        }
        self.showsPlaybackControls = false
        if !self.autoPlayVideos { self.player?.pause() } else if isPlaying { self.player?.play() }
      }
    }
  }
}

extension AVPlayer {
  var isVideoPlaying: Bool {
    return rate != 0 && error == nil
  }
}
