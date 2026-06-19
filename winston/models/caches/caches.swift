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
  static let videos: BaseCache<SharedVideo> = {
    // iOS allows only ~16 simultaneous video decode pipelines. Each cached AVPlayer holding a
    // ready item keeps one warm, so cap well under that and fully tear down the evicted player
    // on overflow — otherwise old players pile up over a long session and starve new videos
    // (no autoplay in the list; a frame then a stall in the post, until a force-restart).
    let cache = BaseCache<SharedVideo>(cacheLimit: 12)
    cache.onEvict = { evicted in
      evicted.player.pause()
      evicted.player.replaceCurrentItem(with: nil)
    }
    return cache
  }()
  static let streamable = BaseCache<StreamableCached>(cacheLimit: 100)
}
