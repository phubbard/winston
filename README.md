![Winston Logo](https://i.imgur.com/axc6Rq3.png)

[![Build](https://github.com/phubbard/winston/actions/workflows/build.yml/badge.svg)](https://github.com/phubbard/winston/actions/workflows/build.yml)
![License](https://img.shields.io/github/license/phubbard/winston)
[![Platform](http://img.shields.io/badge/platform-iOS/iPadOS-blue.svg)](https://developer.apple.com/iphone/index.action)
![GitHub issues](https://img.shields.io/github/issues-raw/phubbard/winston)
![GitHub release](https://img.shields.io/github/v/release/phubbard/winston)

Winston is a privacy-focused, open-source Reddit client for iOS. No analytics, no tracking, no ads, no third-party data collection — your data stays on your device and the app communicates only with Reddit's API. This is an actively maintained fork of the original [lo-cafe/winston](https://github.com/lo-cafe/winston).

## Privacy

- **No analytics or tracking** — zero telemetry, no usage data collected
- **No ads or ad networks** — no advertising SDKs of any kind
- **No third-party data collection** — removed all upstream phone-home code (ThemeStore, WinstonAPI)
- **Communicates only with Reddit** — the only network calls are to Reddit's OAuth and API endpoints
- **Open source** — audit the code yourself

## Installing

Winston requires iOS 17+ and your own Reddit API credentials.

1. Clone the repo and open `winston.xcodeproj` in Xcode
2. Set your development team and bundle identifier in the project settings
3. Build and run on your device
4. Follow the in-app credential setup to connect your Reddit account

## Changes from upstream

- Fixed broken tab bar (buttons not responding to taps)
- Fixed scroll jumping when loading new content
- Fixed post text truncation
- Fixed startup blur race condition
- Fixed cross-tab navigation (e.g. "Go to credentials settings")
- Auto-select credentials after first setup
- OAuth redirect via custom URL scheme (no dependency on winston.cafe)
- Updated branding, FAQ, and links for this fork
- Replaced CI with simple build + release workflows
- Fixed duplicate subreddits in the subs list
- Removed ThemeStore and WinstonAPI third-party phone-home code
- Added dark mode / light mode / system appearance setting
- Fixed feed switching error when navigating between Home/Popular/All/Saved
- Auto build numbers from git commit count

## Contributing

Pull requests welcome against `main`. Please open an issue first for larger changes.

## Links

- [Report a bug](https://github.com/phubbard/winston/issues)
- [Original Winston by lo.cafe](https://github.com/lo-cafe/winston)

## License

Winston is open-source, licensed under the GPL-3.0 license. See the LICENSE file for details.
