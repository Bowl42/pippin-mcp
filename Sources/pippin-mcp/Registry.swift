import PippinServer

func buildRegistry() -> ToolRegistry {
    ToolRegistry(entries: [
        ToolRegistry.register(OCRTool.self),
        ToolRegistry.register(ClassifyTool.self),
        ToolRegistry.register(NLAnalyzeTool.self),
        ToolRegistry.register(TranslateTool.self),
        ToolRegistry.register(FMGenerateTool.self),
    ])
}
