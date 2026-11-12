local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ChatBubbleLayout = ns.ChatBubbleLayout or require("WhisperMessenger.UI.ChatBubble.Layout")
local FramePool = ns.ChatBubbleFramePool or require("WhisperMessenger.UI.ChatBubble.FramePool")
local ScrollView = ns.ScrollView or require("WhisperMessenger.UI.ScrollView")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local TranscriptRows = ns.ConversationPaneTranscriptRows or require("WhisperMessenger.UI.ConversationPane.TranscriptRows")
local TranscriptRowGeometry = ns.ConversationPaneTranscriptRowGeometry or require("WhisperMessenger.UI.ConversationPane.TranscriptRowGeometry")
local DisplayName = ns.DisplayName or require("WhisperMessenger.Util.DisplayName")
local sizeValue = UIHelpers.sizeValue

local TranscriptVirtualization = {}

local END_TOLERANCE = 1

local totalHeight = TranscriptRowGeometry.TotalHeight
local recomputeOffsets = TranscriptRowGeometry.RecomputeOffsets
local rangeForOffset = TranscriptRowGeometry.RangeForOffset
local captureAnchor = TranscriptRowGeometry.CaptureAnchor
local anchoredOffset = TranscriptRowGeometry.AnchoredOffset

local function isAtEnd(transcript)
  local range = ScrollView.GetRange(transcript)
  return range <= 0 or ScrollView.GetOffset(transcript) >= range - END_TOLERANCE
end

-- Returns totalHeight, relaidOut. relaidOut is false when the visible range is
-- unchanged and `force` is not set, which is the allocation-free skip path the
-- background status refresh takes when nothing about the conversation changed.
-- `rebuild` drops every visible bubble; otherwise rows that did not change keep
-- theirs.
local function bindOffset(transcript, state, requestedOffset, snapToEnd, force, rebuild)
  if transcript._renderingViewport then
    return state.totalHeight, false
  end

  local rows = state.rows
  if #rows == 0 then
    FramePool.initPool(transcript.content)
    FramePool.releaseAll(transcript.content)
    transcript._virtualFirstIndex = nil
    transcript._virtualLastIndex = nil
    transcript._renderingViewport = true
    ScrollView.RefreshMetrics(transcript, 0, false)
    state.totalHeight = 0
    transcript._renderingViewport = false
    return state.totalHeight, true
  end

  local viewportHeight = sizeValue(transcript.scrollFrame, "GetHeight", "height", transcript.viewportHeight or 0)
  if viewportHeight <= 0 then
    viewportHeight = transcript.viewportHeight or 0
  end
  local targetOffset = snapToEnd and math.max(state.totalHeight - viewportHeight, 0) or requestedOffset
  local anchorMessage, anchorDelta, anchorIndex = captureAnchor(rows, targetOffset)
  local firstIndex, lastIndex = rangeForOffset(rows, targetOffset, viewportHeight)
  if not force and firstIndex == state.firstIndex and lastIndex == state.lastIndex and state.viewportHeight == viewportHeight then
    return state.totalHeight, false
  end

  state.viewportHeight = viewportHeight
  transcript._renderingViewport = true
  local settled = false
  local passCap = #rows + 1
  local reuse = not rebuild
  for _ = 1, passCap do
    local _, firstChanged = ChatBubbleLayout.LayoutRange(
      transcript.factory,
      transcript.content,
      state.messages,
      rows,
      firstIndex,
      lastIndex,
      state.paneWidth,
      state.options,
      reuse
    )
    reuse = true
    if firstChanged then
      state.totalHeight = recomputeOffsets(rows, firstChanged)
    else
      state.totalHeight = totalHeight(rows)
    end

    if snapToEnd then
      targetOffset = math.max(state.totalHeight - viewportHeight, 0)
    else
      targetOffset = anchoredOffset(rows, anchorMessage, anchorDelta, anchorIndex) or targetOffset
    end

    local nextFirst, nextLast = rangeForOffset(rows, targetOffset, viewportHeight)
    state.firstIndex = firstIndex
    state.lastIndex = lastIndex
    transcript._virtualFirstIndex = firstIndex
    transcript._virtualLastIndex = lastIndex
    if nextFirst == firstIndex and nextLast == lastIndex then
      settled = true
      break
    end
    firstIndex = nextFirst
    lastIndex = nextLast
  end

  if not settled then
    local _, firstChanged = ChatBubbleLayout.LayoutRange(
      transcript.factory,
      transcript.content,
      state.messages,
      rows,
      firstIndex,
      lastIndex,
      state.paneWidth,
      state.options,
      true
    )
    if firstChanged then
      state.totalHeight = recomputeOffsets(rows, firstChanged)
    else
      state.totalHeight = totalHeight(rows)
    end
    if snapToEnd then
      targetOffset = math.max(state.totalHeight - viewportHeight, 0)
    else
      targetOffset = anchoredOffset(rows, anchorMessage, anchorDelta, anchorIndex) or targetOffset
    end
    state.firstIndex = firstIndex
    state.lastIndex = lastIndex
    transcript._virtualFirstIndex = firstIndex
    transcript._virtualLastIndex = lastIndex
  end

  local measuredTotalHeight = state.totalHeight
  ScrollView.RefreshMetrics(transcript, measuredTotalHeight, snapToEnd)
  state.totalHeight = measuredTotalHeight
  if not snapToEnd then
    ScrollView.SetVerticalScroll(transcript, targetOffset)
  end
  transcript._renderingViewport = false
  -- SetVerticalScroll may be clamped by the native scroll child while its
  -- rectangle settles. Its synchronous event was deliberately ignored above;
  -- bind the actual range once now instead of waiting for a user scroll.
  local actualOffset = ScrollView.GetOffset(transcript)
  local actualFirst, actualLast = rangeForOffset(rows, actualOffset, viewportHeight)
  if not transcript._settlingViewport and (actualFirst ~= state.firstIndex or actualLast ~= state.lastIndex) then
    transcript._settlingViewport = true
    bindOffset(transcript, state, actualOffset, false, false, false)
    transcript._settlingViewport = nil
  end
  return state.totalHeight, true
end

function TranscriptVirtualization.Render(transcript, messages, paneWidth, options, renderOptions)
  local previousState = transcript._virtualState
  local previousRows = previousState and previousState.rows or nil
  local previousOffset = transcript._virtualRequestedOffset or ScrollView.GetOffset(transcript)
  transcript._virtualRequestedOffset = nil
  local hadRows = previousRows ~= nil and #previousRows > 0
  local requestedEnd = transcript._virtualForceEnd
  local forceSnapToEnd = requestedEnd == true
  transcript._virtualForceEnd = nil
  local snapToEnd = forceSnapToEnd or not hadRows or (requestedEnd == nil and isAtEnd(transcript))
  local anchorMessage, anchorDelta, anchorIndex
  if hadRows and not snapToEnd then
    anchorMessage, anchorDelta, anchorIndex = captureAnchor(previousRows, previousOffset)
  end

  local dividerMessage = options and options.unreadDividerMessage or nil
  local state, anyChanged = TranscriptRows.Prepare(transcript, messages, paneWidth, dividerMessage)
  state.options = options
  local fallbackClassTag = options and options.fallbackClassTag or nil
  local senderFallbackClassTag = options and options.senderFallbackClassTag or nil
  local displayNameRevision = DisplayName.Revision()
  -- Bubble geometry is keyed off the row diff, but the fallback class tags and
  -- the display-name rules only change sender names, so they are tracked separately.
  -- Those reach every row, so they rebuild all bubbles; a row diff (new,
  -- dropped or edited messages) rebuilds only the rows it marked stale.
  local rebuild = (renderOptions and renderOptions.force == true)
    or not hadRows
    or forceSnapToEnd
    or state.fallbackClassTag ~= fallbackClassTag
    or state.senderFallbackClassTag ~= senderFallbackClassTag
    or state.displayNameRevision ~= displayNameRevision
    or state.chatLocked ~= (options and options.chatLocked)
  local force = rebuild or anyChanged
  state.fallbackClassTag = fallbackClassTag
  state.senderFallbackClassTag = senderFallbackClassTag
  state.displayNameRevision = displayNameRevision
  state.chatLocked = options and options.chatLocked

  local targetOffset = previousOffset
  if anchorMessage then
    targetOffset = anchoredOffset(state.rows, anchorMessage, anchorDelta, anchorIndex) or targetOffset
  end
  -- Opening a chat always shows the latest messages; the unread divider only
  -- marks where the new block starts and never pulls the view away from the end.
  local _, relaidOut = bindOffset(transcript, state, targetOffset, snapToEnd, force, rebuild)

  local settledWidth = sizeValue(transcript.scrollFrame, "GetWidth", "width", paneWidth)
  if settledWidth > 0 and settledWidth ~= paneWidth then
    -- The scrollbar may consume width. Capture before Prepare replaces the
    -- measured row heights with estimates at that final width.
    local settledOffset = ScrollView.GetOffset(transcript)
    local message, delta, index = captureAnchor(state.rows, settledOffset)
    local settledChanged
    state, settledChanged = TranscriptRows.Prepare(transcript, messages, settledWidth, dividerMessage)
    state.options = options
    state.fallbackClassTag = fallbackClassTag
    state.senderFallbackClassTag = senderFallbackClassTag
    state.displayNameRevision = displayNameRevision
    state.chatLocked = options and options.chatLocked
    if not snapToEnd then
      settledOffset = anchoredOffset(state.rows, message, delta, index) or settledOffset
    end
    local _, settledRelaidOut = bindOffset(transcript, state, settledOffset, snapToEnd, force or settledChanged, rebuild)
    relaidOut = relaidOut or settledRelaidOut
  end
  return state.totalHeight, state.firstIndex, state.lastIndex, relaidOut
end

function TranscriptVirtualization.RefreshViewport(transcript)
  local state = transcript and transcript._virtualState or nil
  if state == nil or transcript._renderingViewport then
    return false
  end
  local width = sizeValue(transcript.scrollFrame, "GetWidth", "width", state.paneWidth)
  if width <= 0 then
    return false
  end
  if width ~= state.paneWidth then
    local _, _, _, relaidOut = TranscriptVirtualization.Render(transcript, state.messages, width, state.options)
    return relaidOut
  end
  local _, relaidOut = bindOffset(transcript, state, ScrollView.GetOffset(transcript), isAtEnd(transcript), false, false)
  return relaidOut
end

function TranscriptVirtualization.Reset(transcript)
  transcript._virtualState = nil
  transcript._positionedDivider = nil
  transcript._virtualFirstIndex = nil
  transcript._virtualLastIndex = nil
  transcript._virtualRequestedOffset = nil
  transcript._virtualForceEnd = nil
end

ns.ConversationPaneTranscriptVirtualization = TranscriptVirtualization
return TranscriptVirtualization
