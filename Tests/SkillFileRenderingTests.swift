import Foundation
import Testing
@testable import YouSkill

@Suite
struct SkillFileRenderingTests {
    @Test
    func browserURLUsesResolvedBranchAndPath() {
        let skill = Skill(
            id: 1,
            name: "demo",
            description: nil,
            url: "https://github.com/octo-org/demo-skill.git",
            path: "skills/core",
            starCount: 0,
            heatScore: 0,
            installCount: 0,
            source: "octo-org/demo-skill",
            branch: "release/v1",
            skillPathSHA: nil,
            tags: [],
            createdAt: .now,
            updatedAt: .now
        )

        let url = skill.browserURL(for: "docs/with space.txt")

        #expect(
            url?.absoluteString
                == "https://github.com/octo-org/demo-skill/blob/release/v1/skills/core/docs/with%20space.txt"
        )
    }

    @Test
    func codeLikeExtensionsAreRenderedAsCode() {
        #expect(SkillFileKind(path: ".env") == .code)
        #expect(SkillFileKind(path: "logs/build.log") == .code)
        #expect(SkillFileKind(path: "icons/logo.svg") == .code)
    }
}
