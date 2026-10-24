import Testing
@testable import YouSkill

@Suite
struct BilingualMarkdownTests {
    @Test
    func splitsCommonBlocks() {
        let markdown = """
        # Title

        First paragraph
        continues here.

        - one
        - two

        ```swift
        let a = 1

        let b = 2
        ```

        | A | B |
        |---|---|
        | 1 | 2 |

        > Quote

        ---
        """

        let kinds = MarkdownBlockParser.blocks(in: markdown).map(\.kind)

        #expect(kinds == [
            .heading(level: 1, text: "Title"),
            .paragraph,
            .list,
            .code,
            .table,
            .blockquote,
            .thematicBreak
        ])
    }

    @Test
    func paragraphsStackOriginalThenTranslation() {
        let segments = BilingualMarkdownAligner.segments(
            original: "Read the guide.\n\nThen run it.",
            translated: "阅读指南。\n\n然后运行。"
        )

        #expect(segments == [
            .stacked(original: "Read the guide.", translated: "阅读指南。"),
            .stacked(original: "Then run it.", translated: "然后运行。")
        ])
    }

    @Test
    func headingTranslationBecomesSecondLineOfSameHeading() {
        let segments = BilingualMarkdownAligner.segments(
            original: "## Workflow ##",
            translated: "## 工作流程"
        )

        #expect(segments == [.heading(level: 2, original: "Workflow", translated: "工作流程")])
    }

    @Test
    func listItemsArePairedOneByOne() {
        let segments = BilingualMarkdownAligner.segments(
            original: "1. Read the instructions.\n2. Review the result.",
            translated: "1. 阅读说明。\n2. 检查结果。"
        )

        #expect(segments == [
            .list("1. Read the instructions.\n\n   阅读说明。\n\n2. Review the result.\n\n   检查结果。\n")
        ])
    }

    @Test
    func listsWithDifferentItemCountsStackAsWholeBlocks() {
        let segments = BilingualMarkdownAligner.segments(
            original: "- a\n- b",
            translated: "- 甲乙"
        )

        #expect(segments == [.stacked(original: "- a\n- b", translated: "- 甲乙")])
    }

    @Test
    func nestedListContentStaysInsideTheItem() {
        let segments = BilingualMarkdownAligner.segments(
            original: "- Parent\n  - Child",
            translated: "- 父项\n  - 子项"
        )

        #expect(segments == [.list("- Parent\n  - Child\n\n  父项\n  - 子项\n")])
    }

    @Test
    func tablesStackWholeOriginalThenWholeTranslation() {
        let original = "| Name | Use |\n|---|---|\n| a | first |"
        let translated = "| 名称 | 用途 |\n|---|---|\n| a | 第一 |"

        let segments = BilingualMarkdownAligner.segments(original: original, translated: translated)

        #expect(segments == [.stacked(original: original, translated: translated)])
    }

    @Test
    func codeAndIdenticalBlocksAppearOnce() {
        let segments = BilingualMarkdownAligner.segments(
            original: "Intro\n\n```sh\nmake test\n```\n\n`npm run build`",
            translated: "介绍\n\n```sh\nmake test\n```\n\n`npm run build`"
        )

        #expect(segments == [
            .stacked(original: "Intro", translated: "介绍"),
            .original("```sh\nmake test\n```"),
            .original("`npm run build`")
        ])
    }

    @Test
    func unmatchedBlocksKeepTheirPlace() {
        let segments = BilingualMarkdownAligner.segments(
            original: "# Title\n\nBody",
            translated: "# 标题\n\n> 注\n\n正文"
        )

        #expect(segments == [
            .heading(level: 1, original: "Title", translated: "标题"),
            .translated("> 注"),
            .stacked(original: "Body", translated: "正文")
        ])
    }

    @Test
    func setextHeadingsAreHeadings() {
        let blocks = MarkdownBlockParser.blocks(in: "Title\n=====\n\nSub\n---")

        #expect(blocks.map(\.kind) == [.heading(level: 1, text: "Title"), .heading(level: 2, text: "Sub")])
    }
}
