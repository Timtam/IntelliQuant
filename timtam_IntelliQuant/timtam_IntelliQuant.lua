-- module requirements for all actions
-- doesn't provide any action by itself, so don't map any shortcut to it or run this action

-- fixing script path for correct require calls
local path = ({reaper.get_action_context()})[2]:match('^.+[\\//]')
package.path = path .. "?.lua"

-- other packages
local smallfolk = require('smallfolk')

-- constants

local activeProjectIndex = 0
local sectionName = "com.timtam.IntelliQuant"

local deserializeTable = smallfolk.loads
local serializeTable = smallfolk.dumps

-- source: stackoverflow (https://stackoverflow.com/questions/11669926/is-there-a-lua-equivalent-of-scalas-map-or-cs-select-function)
local function map(f, t)
  local t1 = {}
  local t_len = #t
  for i = 1, t_len do
    t1[i] = f(t[i])
  end
  return t1
end

local function setValuePersist(key, value)
  reaper.SetProjExtState(activeProjectIndex, sectionName, key, value)
end

local function getValuePersist(key, defaultValue)

  local valueExists, value = reaper.GetProjExtState(activeProjectIndex, sectionName, key)

  if valueExists == 0 then
    setValuePersist(key, defaultValue)
    return defaultValue
  end

  return value
end

local function setValue(key, value)
  reaper.SetExtState(sectionName, key, value, false)
end

local function getValue(key, defaultValue)

  local valueExists = reaper.HasExtState(sectionName, key)

  if valueExists == false then
    setValue(key, defaultValue)
    return defaultValue
  end

  local value = reaper.GetExtState(sectionName, key)

  return value
end

local function print(message)

  if type(message) == "table" then
    message = serializeTable(message)
  end

  reaper.ShowConsoleMsg("AccessiChords: "..tostring(message).."\n")
end

local function speak(text)
  if reaper.osara_outputMessage ~= nil then
    reaper.osara_outputMessage(text)
  end
end

local function getActiveMidiTake()

  local activeMidiEditor = reaper.MIDIEditor_GetActive()

  return reaper.MIDIEditor_GetTake(activeMidiEditor)
end

local function getCursorPosition()
  return reaper.GetCursorPosition()
end

local function getCursorPositionPPQ()
  return reaper.MIDI_GetPPQPosFromProjTime(getActiveMidiTake(), getCursorPosition())
end

local function getActiveMediaItem()
  return reaper.GetMediaItemTake_Item(getActiveMidiTake())
end

local function getMediaItemStartPosition()
  return reaper.GetMediaItemInfo_Value(getActiveMediaItem(), "D_POSITION")
end

local function getMediaItemStartPositionPPQ()
  return reaper.MIDI_GetPPQPosFromProjTime(getActiveMidiTake(), getMediaItemStartPosition())
end

local function getMediaItemStartPositionQN()
  return reaper.MIDI_GetProjQNFromPPQPos(getActiveMidiTake(), getMediaItemStartPositionPPQ())
end

local function getGridUnitLength()

  local gridLengthQN = reaper.MIDI_GetGrid(getActiveMidiTake())
  local gridLengthPPQ = reaper.MIDI_GetPPQPosFromProjQN(getActiveMidiTake(), gridLengthQN)
  local gridLength = reaper.MIDI_GetProjTimeFromPPQPos(getActiveMidiTake(), gridLengthPPQ)
  return gridLength
end

local function getNextNoteLength()

  local activeMidiEditor = reaper.MIDIEditor_GetActive()
  
  if activeMidiEditor == nil then
    return 0
  end
  
  local noteLen = reaper.MIDIEditor_GetSetting_int(activeMidiEditor, "default_note_len")

  if noteLen == 0 then
    return 0
  end

  return reaper.MIDI_GetProjTimeFromPPQPos(getActiveMidiTake(), noteLen)
end

local function getMidiEndPositionPPQ()

  local startPosition = getCursorPosition()
  local startPositionPPQ = getCursorPositionPPQ()

  local noteLength = getNextNoteLength()
  
  if noteLength == 0 then
    noteLength = getGridUnitLength()
  end

  local endPositionPPQ = reaper.MIDI_GetPPQPosFromProjTime(getActiveMidiTake(), startPosition+noteLength)

  return endPositionPPQ
end

local function insertMidiNotes(...)

  local startPositionPPQ = getCursorPositionPPQ()
  local endPositionPPQ = getMidiEndPositionPPQ()

  local channel = getCurrentNoteChannel()
  local take = getActiveMidiTake()
  local velocity = getCurrentVelocity()
  local _, note

  for _, note in pairs({...}) do
    reaper.MIDI_InsertNote(take, false, false, startPositionPPQ, endPositionPPQ, channel, note, velocity, false)
  end

  local endPosition = reaper.MIDI_GetProjTimeFromPPQPos(take, endPositionPPQ)

  reaper.SetEditCurPos(endPosition, true, false)
end

local function requestUserConfiguration(valueName, title)

  local tValue = deserializeTable(getValue(valueName, '{}'))

  local sValue = tostring(tValue.adjustment_lookahead or 0) .. "," .. tostring(tValue.adjustment_lookbehind or 0) .. "," .. tostring(tValue.detection_lookahead or 0) .. "," .. tostring(tValue.detection_lookbehind or 0)

  local success, sValue = reaper.GetUserInputs(title, 4, "Lookahead for adjustment window in %,Lookbehind for adjustment window in %,Lookahead for detection window in %,Lookbehind for detection window in %", sValue)

  if not success then
    return
  end
  
  local adjustment_la, adjustment_lb, detection_la, detection_lb = string.match(sValue, "(%d+),(%d+),(%d+),(%d+)")

  tValue.adjustment_lookahead = tonumber(adjustment_la)
  tValue.adjustment_lookbehind = tonumber(adjustment_lb)
  tValue.detection_lookahead = tonumber(detection_la)
  tValue.detection_lookbehind = tonumber(detection_lb)
  
  setValue(valueName, serializeTable(tValue))

end

return {
  deserializeTable = deserializeTable,
  getValue = getValue,
  getValuePersist = getValuePersist,
  insertMidiNotes = insertMidiNotes,
  map = map,
  print = print,
  requestUserConfiguration = requestUserConfiguration,
  serializeTable = serializeTable,
  setValue = setValue,
  setValuePersist = setValuePersist,
  speak = speak,
}