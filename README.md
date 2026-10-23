# YouSkill

Discover and read Agent Skills on your iPhone.

YouSkill helps you browse, search, and read MCP (Model Context Protocol) Skills with syntax-highlighted code preview and built-in translation.

## Screenshots

Version 1.1: browse categories and popular repositories, explore skills, and read their files.

<p align="center">
  <img src="screenshots/iphone/01-categories.png" width="200" alt="Browse skill categories on iPhone" />
  <img src="screenshots/iphone/02-repositories.png" width="200" alt="Browse popular repositories on iPhone" />
  <img src="screenshots/iphone/03-skills.png" width="200" alt="Explore a repository's skills on iPhone" />
  <img src="screenshots/iphone/04-reader.png" width="200" alt="Read a skill document on iPhone" />
</p>

<p align="center">
  <img src="screenshots/duo/02-repositories.png" width="48%" alt="Browse popular repositories beside the skill list on iPhone Duo" />
  <img src="screenshots/duo/04-reader.png" width="48%" alt="Read a skill document beside the catalog on iPhone Duo" />
</p>

## Download

<a href="https://apps.apple.com/app/youskill/id6761548607">
  <img src="https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg" height="50" />
</a>

## Features

- Browse and search Agent Skills
- Syntax-highlighted code preview for 30+ languages
- Markdown rendering with rich formatting
- Built-in translation powered by Chat Completion APIs
- File tree navigation with directory structure
- Bookmark your favorite Skills
- Multi-language support: English, 简体中文, 日本語, 한국어

## Tech Stack

- **Language**: Swift 6 with strict concurrency
- **UI**: SwiftUI
- **Minimum Target**: iOS 17.0
- **Architecture**: Layered domain architecture
- **Dependencies**:
  - [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui) — Markdown rendering
  - [HighlightSwift](https://github.com/appstefan/highlightswift) — Syntax highlighting
- **Build**: [XcodeGen](https://github.com/yonaskolb/XcodeGen) for project generation

## Related Projects

- [YouSkill Desktop](https://github.com/wanggang316/you-skill) — macOS / Windows desktop app
- [youskill.cc](https://youskill.cc) — Official website

## License

This project is licensed under the [MIT License](LICENSE).
