public enum WhisperSocketEvent: String, CaseIterable, Equatable, Sendable {
    case health
    case away
    case presence
    case messageSend = "message:send"
    case messageNew = "message:new"
    case messageRecall = "message:recall"
    case messageRecalled = "message:recalled"
    case messageUpdate = "message:update"
    case messagesSearch = "messages:search"
    case read = "read"
    case readUpdate = "read:update"
    case sharedSet = "shared:set"
    case sharedUpdate = "shared:update"
    case actionConfirm = "action:confirm"
    case aiTyping = "ai:typing"
    case aiReplying = "ai:replying"
    case aiActivity = "ai:activity"
    case personalItemChanged = "personalItem:changed"
}
