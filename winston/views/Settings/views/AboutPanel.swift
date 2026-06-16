//
//  AboutPanel.swift
//  winston
//
//  Created by Igor Marcossi on 01/08/23.
//

import SwiftUI

struct AboutPanel: View {
  let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
  let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
  @Environment(\.openURL) private var openURL
  @Environment(\.useTheme) private var theme
  var body: some View {
    List {
      Group {
        Section {
          HStack {
            Image("winstonNoBG")
              .resizable()
              .scaledToFit()
              .frame(width: 48, height: 48)
            
            VStack(alignment: .leading) {
              Text("Winston")
                .fontSize(20, .bold)
              HStack{
                Text("v" + (appVersion ?? "-1") + " Build \(build ?? "-1")")
              }
            }
          }
          
          Text("Winston is a privacy-focused, open-source Reddit client. No analytics, no tracking, no ads, no third-party data collection. Your data stays on your device.")

          WListButton {
            openURL(URL(string: "https://github.com/phubbard/winston")!)
          } label: {
            Label("View on GitHub", systemImage: "arrow.branch").foregroundStyle(Color.accentColor)
          }

        }

        Section("Privacy") {
          Label("No analytics or tracking", systemImage: "eye.slash.fill")
          Label("No ads or ad networks", systemImage: "xmark.shield.fill")
          Label("No third-party data collection", systemImage: "lock.shield.fill")
          Label("Communicates only with Reddit", systemImage: "network")
        }

        Section {
          Text("Winston is free and open source software, originally created by the lo.cafe team. This fork is maintained by phubbard.")
          WListButton {
            openURL(URL(string: "https://github.com/lo-cafe/winston")!)
          } label: {
            Label("Original Winston Source Code", systemImage: "arrow.branch")
          }
        }
      }
      .themedListSection()
    }
    .themedListBG(theme.lists.bg)
    .navigationTitle("About")
    .navigationBarTitleDisplayMode(.inline)
  }
}

//struct AboutPanel_Previews: PreviewProvider {
//    static var previews: some View {
//        AboutPanel()
//    }
//}
