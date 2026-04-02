import Foundation
import Testing
@testable import YouSkill

struct MarkdownFrontmatterParserTests {
    @Test
    func parsesSimpleDescriptionAndStripsFrontmatter() {
        let markdown = """
        ---
        name: find-skill
        description: Find useful skills for a task.
        ---

        # Title

        Body text
        """

        let parsed = MarkdownFrontmatterParser.parse(markdown)

        #expect(parsed.hasFrontmatter)
        #expect(parsed.frontmatterDescription == "Find useful skills for a task.")
        #expect(parsed.body == "# Title\n\nBody text")
    }

    @Test
    func parsesFoldedDescriptionBlock() {
        let markdown = """
        ---
        description: >
          First line
          second line
        ---

        ## Heading
        """

        let parsed = MarkdownFrontmatterParser.parse(markdown)

        #expect(parsed.frontmatterDescription == "First line second line")
        #expect(parsed.body == "## Heading")
    }

    @Test
    func returnsOriginalContentWhenNoFrontmatterExists() {
        let markdown = """
        # Title

        Body
        """

        let parsed = MarkdownFrontmatterParser.parse(markdown)

        #expect(!parsed.hasFrontmatter)
        #expect(parsed.frontmatterDescription == nil)
        #expect(parsed.body == markdown)
    }
}
