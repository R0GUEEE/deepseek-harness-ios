import Foundation
import XCTest
#if canImport(HarnessMobile)
@testable import HarnessMobile
#else
@testable import HarnessMobileCore
#endif

/// Pins the `session-turn-outline` fold against the upstream contract:
/// `turn/start` anchors entries, the first user prompt fills the preview, the
/// newest text-bearing assistant message buffers a draft that commits at
/// `turn/end`, and boundaries that do not advance the turn keep state stable.
final class SessionTurnOutlineTests: XCTestCase {
    private func event(
        _ type: String,
        seq: UInt64,
        turn: Int? = nil,
        data: JSONValue
    ) -> SessionEvent {
        try! SessionEvent(type: type, seq: seq, time: Int64(seq) * 10, data: data)
    }

    private func userMessage(_ text: String, kind: String = "user") -> SessionEvent {
        event(
            SessionEventVocabulary.userMessage,
            seq: 0,
            data: .object([
                "source": .object(["kind": .string(kind)]),
                "content": .array([
                    .object(["type": .string("text"), "text": .string(text)])
                ])
            ])
        )
    }

    private func assistantMessage(_ text: String) -> SessionEvent {
        event(
            SessionEventVocabulary.assistantMessage,
            seq: 0,
            data: .object([
                "message": .object([
                    "content": .array([
                        .object(["type": .string("text"), "text": .string(text)])
                    ])
                ])
            ])
        )
    }

    private func turnStart(_ turn: Int, seq: UInt64) -> SessionEvent {
        event(
            SessionEventVocabulary.turnStart,
            seq: seq,
            turn: turn,
            data: .object(["turn": .number(Double(turn))])
        )
    }

    private func turnEnd() -> SessionEvent {
        event(
            SessionEventVocabulary.turnEnd,
            seq: 0,
            data: .object(["reason": .object(["kind": .string("completed")])])
        )
    }

    func testFoldCapturesPromptResponseAndDraftAcrossTwoTurns() {
        let state = SessionTurnOutline.fold([
            turnStart(1, seq: 10),
            userMessage("Help me organize this material, with source verification as the focus"),
            assistantMessage("OK, I'll read the file list first."),
            turnEnd(),
            turnStart(2, seq: 50),
            userMessage("Continue and write the conclusions in weekly report format"),
            assistantMessage("The conclusions were written in weekly report format."),
            turnEnd()
        ])
        XCTAssertEqual(state.turns.count, 2)
        XCTAssertEqual(state.turns[0].turn, 1)
        XCTAssertEqual(state.turns[0].seq, 10)
        XCTAssertEqual(state.turns[0].prompt, "Help me organize this material, with source verification as the focus")
        XCTAssertEqual(state.turns[0].response, "OK, I'll read the file list first.")
        XCTAssertEqual(state.turns[1].prompt, "Continue and write the conclusions in weekly report format")
        XCTAssertEqual(state.draft, "")
    }

    func testOpenTurnKeepsDraftAndToolMessagesNeverFillPrompt() {
        let state = SessionTurnOutline.fold([
            turnStart(1, seq: 10),
            userMessage("Let's start", kind: "tool"),
            userMessage("Official goal: verify the ledger numbers"),
            assistantMessage("Processing…"),
        ])
        XCTAssertEqual(state.turns.count, 1)
        // Tool-sourced message does not fill the prompt preview.
        XCTAssertEqual(state.turns[0].prompt, "Official goal: verify the ledger numbers")
        // The open turn keeps its draft instead of committing it.
        XCTAssertEqual(state.draft, "Processing…")
        XCTAssertEqual(state.turns[0].response, "")
    }

    func testNonAdvancingBoundaryAndLongTextPreviewsAreBounded() {
        let longPrompt = String(repeating: "Long", count: 200)
        let state = SessionTurnOutline.fold([
            turnStart(1, seq: 10),
            turnStart(1, seq: 11), // non-advancing boundary: ignored
            userMessage(longPrompt),
            turnEnd()
        ])
        XCTAssertEqual(state.turns.count, 1)
        XCTAssertEqual(state.turns[0].prompt.count, SessionTurnOutline.promptPreviewLimit)
        XCTAssertTrue(state.turns[0].prompt.hasSuffix("…"))
    }

    func testEmptyFoldYieldsEmptyState() {
        XCTAssertEqual(SessionTurnOutline.fold([]), SessionTurnOutlineState.empty)
    }
}
