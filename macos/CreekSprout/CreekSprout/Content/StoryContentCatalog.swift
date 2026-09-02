struct StoryContentCatalog: Sendable {
    static let shared = StoryContentCatalog()

    let stories: [StoryDefinition]
    let actors: [StoryActorDefinition]
    let blockingCues: [StoryBlockingCueDefinition]
    let anchors: [StoryAnchorDefinition]
    let journeyScenes: [StoryJourneySceneDefinition]

    init(
        stories: [StoryDefinition] = StoryGeneratedContent.storyDefinitions,
        actors: [StoryActorDefinition] = StoryActorCatalog.all,
        blockingCues: [StoryBlockingCueDefinition] = StoryBlockingCueCatalog.all,
        anchors: [StoryAnchorDefinition] = StoryAnchorCatalog.all,
        journeyScenes: [StoryJourneySceneDefinition] = StoryAnchorCatalog.journeyScenes
    ) {
        self.stories = stories
        self.actors = actors
        self.blockingCues = blockingCues
        self.anchors = anchors
        self.journeyScenes = journeyScenes
    }

    var storiesByID: [StoryArcID: StoryDefinition] {
        Dictionary(uniqueKeysWithValues: stories.map { ($0.id, $0) })
    }

    var actorsByID: [String: StoryActorDefinition] {
        Dictionary(uniqueKeysWithValues: actors.map { ($0.id, $0) })
    }

    var blockingCuesByID: [String: StoryBlockingCueDefinition] {
        Dictionary(uniqueKeysWithValues: blockingCues.map { ($0.id, $0) })
    }

    var anchorsByID: [String: StoryAnchorDefinition] {
        Dictionary(uniqueKeysWithValues: anchors.map { ($0.id, $0) })
    }

    var journeyScenesByID: [String: StoryJourneySceneDefinition] {
        Dictionary(uniqueKeysWithValues: journeyScenes.map { ($0.id, $0) })
    }

    var allDialogueLines: [StoryDialogueLineDefinition] {
        stories.flatMap { $0.stages.flatMap(\.lines) }
    }

    func story(id: StoryArcID) -> StoryDefinition? {
        stories.first { $0.id == id }
    }

    func stage(arcID: StoryArcID, kind: StoryStageID) -> StoryStageDefinition? {
        story(id: arcID)?.stages.first { $0.kind == kind }
    }

    func blockingCue(id: String) -> StoryBlockingCueDefinition? {
        blockingCues.first { $0.id == id }
    }

    func anchor(id: String) -> StoryAnchorDefinition? {
        anchors.first { $0.id == id }
    }

    /// The ordinary runtime must use this visibility-aware lookup. Raw content
    /// remains available to validation and the finale gallery only.
    func visibleLines(
        arcID: StoryArcID,
        stage: StoryStageID,
        finaleUnlocked: Bool
    ) -> [StoryDialogueLineDefinition] {
        guard let definition = self.stage(arcID: arcID, kind: stage) else { return [] }
        guard finaleUnlocked || definition.visibility == .ordinary else { return [] }
        return definition.lines.filter { finaleUnlocked || $0.visibility == .ordinary }
    }

    func visibleLine(id: String, finaleUnlocked: Bool) -> StoryDialogueLineDefinition? {
        guard let line = allDialogueLines.first(where: { $0.id == id }) else { return nil }
        guard finaleUnlocked || line.visibility == .ordinary else { return nil }
        return line
    }

    func visibleBlockingCue(
        id: String,
        finaleUnlocked: Bool
    ) -> StoryBlockingCueDefinition? {
        guard let cue = blockingCue(id: id) else { return nil }
        guard finaleUnlocked || cue.revealCameraOrProp.policy == .never else { return nil }
        return cue
    }
}

