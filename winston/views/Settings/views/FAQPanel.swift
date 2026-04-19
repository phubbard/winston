//
//  FAQPanel.swift
//  winston
//
//  Created by Daniel Inama on 15/08/23.
//

import SwiftUI

struct FAQPanel: View {
  @Environment(\.useTheme) private var theme
  
  var body: some View {
    
    List{
      Section {
        QuestionAnswer(question: "What does the Box Icon do?", answer: "Save posts in the Posts Box to be read later. These will live in Winston and won't be synced to Reddit.", systemImage: "shippingbox")
        QuestionAnswer(question: "What's Winston Everywhere?", answer: "Winston Everywhere is a Safari extension that automatically redirects Reddit links to Winston.", systemImage: "safari")
        QuestionAnswer(question: "Is Winston against Reddit's TOS?", answer: "Winston uses your own Reddit API key, which is within Reddit's API terms. It's open source and free, and works similarly to any other API client.", systemImage: "checkmark.shield")
        QuestionAnswer(question: "Why do I need my own API key?", answer: "Reddit requires each app to use API credentials. Winston lets you create your own so you're not dependent on anyone else's quota or keys.", systemImage: "key.horizontal")
        QuestionAnswer(question: "Where do I report bugs?", answer: "File an issue on GitHub at [phubbard/winston](https://github.com/phubbard/winston/issues).", systemImage: "ladybug")
        QuestionAnswer(question: "Who maintains this fork?", answer: "This fork is maintained by [phubbard](https://github.com/phubbard). Winston was originally created by the lo.cafe team — [see the original repo](https://github.com/lo-cafe/winston).", systemImage: "person")
      }
      .themedListSection()
    }
    .themedListBG(theme.lists.bg)
    .navigationBarTitle("Frequently Asked Questions", displayMode: .inline)
    
  }
}

struct QuestionAnswer: View {
  var question: String
  var answer: String
  var systemImage: String?
  var body: some View {
    VStack{
      HStack{
        if let systemImage {
          Image(systemName: systemImage)
        }
        Text(.init(question))
        Spacer()
      }
      .fontWeight(.bold)
      .font(.system(.headline))
      .padding(.bottom, 5)
      HStack{
        Text(.init(answer))
        Spacer()
      }
    }
  }
}
