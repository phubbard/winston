//
//  PostLinkSettings.swift
//  winston
//
//  Created by Igor Marcossi on 15/12/23.
//

import Foundation
import Defaults
import SwiftUI

enum ThumbnailSizeModifier: Codable, CaseIterable, Identifiable, Defaults.Serializable {
  var id: CGFloat { self.rawVal }

  case hidden, small, medium, large

  var rawVal: CGFloat {
    switch self {
    case .hidden: return 0.0
    case .small: return 0.75
    case .medium: return 1.0
    case .large: return 1.25
    }
  }
}

enum HSide: String, Equatable, Codable, Hashable, Defaults.Serializable {
  case leading, trailing
}

enum VSide: String, Equatable, Codable, Hashable, Defaults.Serializable {
  case top, bottom
}

struct CompactPostLinkDefSettings: Equatable, Hashable, Codable, Defaults.Serializable {
  var enabled: Bool = false
  var thumbnailSize: ThumbnailSizeModifier = .small
  var thumbnailSide: HSide = .trailing
  var voteButtonsSide: HSide = .trailing
  var showPlaceholderThumbnail: Bool = false
}

struct PostLinkDefSettings: Equatable, Hashable, Codable, Defaults.Serializable {
  var compactMode: CompactPostLinkDefSettings = .init()
  var showAuthor: Bool = true
  var swipeActions: SwipeActionsSet = DEFAULT_POST_SWIPE_ACTIONS
  var showVotesCluster: Bool = true
  var showUpVoteRatio: Bool = false
  var blurNSFW: Bool = true
  var isMediaTappable: Bool = false
  var showSelfText: Bool = true
  var enableVotesPopover: Bool = false
  var maxMediaHeightScreenPercentage: Double = 100
  var readOnScroll: Bool = false
  var lightboxReadsPost: Bool = false
  var dividerPosition: VSide = .bottom
  var titlePosition: VSide = .top
  var hideOnRead: Bool = false
}

//struct ModalsDefSettings: Hashable, Codable, Defaults.Serializable {
//  let showTestersCelebrationModal: Bool
//  let showTipJarModal: Bool
//}
