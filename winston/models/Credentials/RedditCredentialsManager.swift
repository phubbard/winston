//
//  AccountsManager.swift
//  winston
//
//  Created by Igor Marcossi on 19/11/23.
//

import Foundation
import KeychainAccess
import Alamofire
import SwiftUI
import Defaults
import Combine

@Observable
class RedditCredentialsManager {
  static let shared = RedditCredentialsManager()
  static func getById(_ credID: UUID) -> RedditCredential? { RedditCredentialsManager.shared.credentials.first(where: { $0.id == credID } ) }
  static let keychainEntryDivider = "\\--(*.*)--/"
  static let oldKeychainServiceString = "net.phfactor.winston.reddit-credentials"
  static let keychainServiceString = "net.phfactor.winston.reddit-multi-credentials"
  static let keychain = Keychain(service: RedditCredentialsManager.keychainServiceString).synchronizable(Defaults[.BehaviorDefSettings].iCloudSyncCredentials)
  private(set) var credentials: [RedditCredential] = []
  var validCredentials: [RedditCredential] { credentials.filter { $0.validationStatus == .authorized } }
  var cancelables: [Defaults.Observation] = []
    
  var selectedCredential: RedditCredential? {
    if credentials.count > 0 {
      return credentials.first { $0.id == Defaults[.GeneralDefSettings].redditCredentialSelectedID } ?? credentials[0]
    }
    return nil
  }
  
  func syncCredentialsWithKeychain() {
    do {
      let allKeys = try Self.keychain.allKeys()
      for keychainCredID in allKeys {
        if self.credentials.first(where: { $0.id.uuidString == keychainCredID }) == nil {
          try Self.keychain.remove(keychainCredID)
        }
      }
      for cred in self.credentials {
        if let encoded = cred.toStr() {
          try Self.keychain.set(encoded, key: cred.id.uuidString)
        }
      }
    } catch {
      print("Keychain sync error: \(error.localizedDescription)")
    }
  }
  
  init() {
    let okc = Keychain(service: Self.oldKeychainServiceString)
    let kc = Self.keychain
    
    let oldApiAppID = okc["apiAppID"]
    let oldApiAppSecret = okc["apiAppSecret"]
    let oldRefreshToken = okc["refreshToken"]
    
    var importedCredential: RedditCredential? = nil
    if oldApiAppID != nil || oldApiAppSecret != nil || oldRefreshToken != nil {
      importedCredential = .init(apiAppID: oldApiAppID ?? "", apiAppSecret: oldApiAppSecret ?? "", refreshToken: oldRefreshToken)
    }
    
    if let importedCredential = importedCredential {
      credentials.append(importedCredential)
      Defaults[.GeneralDefSettings].redditCredentialSelectedID = importedCredential.id
    }

    try? okc.remove("apiAppID")
    try? okc.remove("apiAppSecret")
    try? okc.remove("refreshToken")
    try? okc.remove("accessToken")
    
    let keychainKeys = kc.allKeys()
    
    keychainKeys.forEach { key in
      if let credStr = kc[key], let decodedCred = credStr.toObj(RedditCredential.self) {
        credentials.append(decodedCred)
      }
    }
      
//    self.cancelables.append(Defaults.observe(.redditCredentialSelectedID) { change in
//      if change.oldValue == change.newValue { return }
//      if let cred = self.credentials.first(where: { $0.id == change.newValue }) {
//        self.updateMe(altCred: cred)
//      }
//      doThisAfter(0) { self.objectWillChange.send() }
//    })
    
//    if let currCredID = Defaults[.redditCredentialSelectedID], let currCred = self.credentials.first(where: { $0.id == currCredID })  {
//      doThisAfter(0.5) { self.updateMe(altCred: currCred) }
//    }
  }
  
  deinit { self.cancelables.forEach { obs in obs.invalidate() } }
  
  func updateMe(altCred: RedditCredential? = nil) {
    Task(priority: .background) { await RedditAPI.shared.fetchMe(force: true, altCredential: altCred) }
    Task(priority: .background) { await RedditAPI.shared.fetchSubsAndSyncCoreData() }
    Task(priority: .background) { await RedditAPI.shared.fetchMyMultis() }
  }
  
  func saveCred(_ cred: RedditCredential, forceCreate: Bool = true) {
    DispatchQueue.main.async {
      if Defaults[.GeneralDefSettings].onboardingState != .dismissed {
        Defaults[.GeneralDefSettings].onboardingState = .dismissed
        Nav.shared.presentingSheetsQueue = Nav.shared.presentingSheetsQueue.filter { $0 != .onboarding }
      }
      if let i = self.credentials.firstIndex(where: { $0.id == cred.id }) {
        self.credentials[i] = cred
      } else if forceCreate {
        self.credentials.append(cred)
      }
      // Auto-select if no credential is currently selected
      if Defaults[.GeneralDefSettings].redditCredentialSelectedID == nil {
        Defaults[.GeneralDefSettings].redditCredentialSelectedID = cred.id
      }
      // Sync immediately on main queue to avoid XPC violations
      self.syncCredentialsWithKeychain()
    }
  }
  
  func deleteCred(_ cred: RedditCredential) {
    DispatchQueue.main.async {
      withAnimation {
        self.credentials = self.credentials.filter { $0.id != cred.id }
      }
      // Sync immediately on main queue to avoid XPC violations
      self.syncCredentialsWithKeychain()
    }
  }

  
  func wipeAllCredentials() {
    DispatchQueue.main.async {
      withAnimation { self.credentials.removeAll() }
      // Remove keychain items immediately to avoid XPC violations
      do {
        try Self.keychain.removeAll()
      } catch {
        print("Error wiping keychain: \(error.localizedDescription)")
      }
    }
  }
}
