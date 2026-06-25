//
//  cache.swift
//  winston
//
//  Created by Igor Marcossi on 20/09/23.
//

import Foundation
import YouTubePlayerKit
import NukeUI
import UIKit

// WE SHOULD AVOID USING THIS TYPE OF CACHE
// Don't create any more caches in this format,
// there's no reason for the cache to be managed by us manually this way.

class Caches {
  static let postsAttrStr = BaseCache<AttributedString>(cacheLimit: 100)
  // The decode-pipeline leak is per-AVPlayerLayer, not per-AVPlayer, so the inline player view
  // (InlinePlayerLayer) owns layer teardown. We deliberately do NOT replaceCurrentItem(nil) on
  // eviction: PostWinstonData strongly retains the same SharedVideo, so niling its item left a
  // dead/blank video on scroll-back. Just cap the dictionary.
  static let videos = BaseCache<SharedVideo>(cacheLimit: 12)
  static let streamable = BaseCache<StreamableCached>(cacheLimit: 100)
}
