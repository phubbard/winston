//
//  AppearanceDefSettings.swift
//  winston
//
//  Created by Igor Marcossi on 15/12/23.
//

import Defaults
import SwiftUI

enum AppColorScheme: String, Codable, CaseIterable, Defaults.Serializable {
  case system, light, dark

  var label: String {
    switch self {
    case .system: return "System"
    case .light: return "Light"
    case .dark: return "Dark"
    }
  }

  var colorScheme: ColorScheme? {
    switch self {
    case .system: return nil
    case .light: return .light
    case .dark: return .dark
    }
  }
}

struct AppearanceDefSettings: Equatable, Hashable, Codable, Defaults.Serializable {
  var replyModalBlurBackground: Bool = true
  var newPostModalBlurBackground: Bool = true
  var showUsernameInTabBar: Bool = false
  var disableAlphabetLettersSectionsInSubsList: Bool = false
  var themeStoreTint: Bool = true
  var shinyTextAndButtons: Bool = false
  var colorScheme: AppColorScheme = .system
}
