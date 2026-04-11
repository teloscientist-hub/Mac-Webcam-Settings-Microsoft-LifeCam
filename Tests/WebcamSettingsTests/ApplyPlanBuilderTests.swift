import Testing
@testable import WebcamSettings

@Test
func applyPlanBuilderPreservesRequiredOrdering() {
    let builder = ApplyPlanBuilder()
    let ordered = builder.buildOrderedValues(from: [
        .zoom: .int(10),
        .focusAuto: .bool(false),
        .focus: .int(20),
        .whiteBalanceAuto: .bool(false),
        .brightness: .int(55)
    ])

    #expect(ordered.map(\.0) == [.whiteBalanceAuto, .focusAuto, .focus, .brightness, .zoom])
}
