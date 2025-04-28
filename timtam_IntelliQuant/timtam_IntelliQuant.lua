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

  reaper.ShowConsoleMsg("IntelliQuant: "..tostring(message).."\n")
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

local function getMediaItemLength()
  return reaper.GetMediaItemInfo_Value(getActiveMediaItem(), "D_LENGTH")
end

local function getMediaItemStartPositionPPQ()
  return reaper.MIDI_GetPPQPosFromProjTime(getActiveMidiTake(), getMediaItemStartPosition())
end

local function getMediaItemEndPositionPPQ()
  return getMediaItemStartPositionPPQ() + reaper.MIDI_GetPPQPosFromProjTime(getActiveMidiTake(), getMediaItemLength())
end

local function requestUserConfiguration(valueName, title)

  local tValue = deserializeTable(getValue(valueName, '{}'))

  local sValue = tostring(tValue.adjustment_lookahead or 0) .. "," .. tostring(tValue.adjustment_lookbehind or 0) .. "," .. tostring(tValue.detection_lookahead or 0) .. "," .. tostring(tValue.detection_lookbehind or 0) .. "," .. tostring(tValue.flam or 0)

  local success, sValue = reaper.GetUserInputs(title, 5, "Lookahead for adjustment window in %,Lookbehind for adjustment window in %,Lookahead for detection window in %,Lookbehind for detection window in %,Flam detection window in % (enter 0 to disable)", sValue)

  if not success then
    return
  end
  
  local adjustment_la, adjustment_lb, detection_la, detection_lb, flam = string.match(sValue, "(%d+),(%d+),(%d+),(%d+),(%d+)")

  tValue.adjustment_lookahead = tonumber(adjustment_la)
  tValue.adjustment_lookbehind = tonumber(adjustment_lb)
  tValue.detection_lookahead = tonumber(detection_la)
  tValue.detection_lookbehind = tonumber(detection_lb)
  tValue.flam = tonumber(flam)
  
  setValue(valueName, serializeTable(tValue))

end

local function getItemPPQ()

  local take = getActiveMidiTake()
  local item = getActiveMediaItem()
  local position = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
  local offset   = reaper.GetMediaItemTakeInfo_Value(take, 'D_STARTOFFS')
  local qn = reaper.TimeMap2_timeToQN(nil, position - offset)
  ppq = reaper.MIDI_GetPPQPosFromProjQN(take, qn + 1)

  return ppq
end

local function getGridUnitLength()

  local gridLengthQN = reaper.MIDI_GetGrid(getActiveMidiTake())
  return gridLengthQN * getItemPPQ()
end

local function getParametersForGridLength(gridLength)
  if gridLength == 8 then
    return getValue("32parameters", '{}')
  elseif gridLength == 4 then
    return getValue("16parameters", '{}')
  elseif gridLength == 2 then
    return getValue("8parameters", '{}')
  elseif gridLength == 1 then
    return getValue("4parameters", '{}')
  elseif gridLength == 3 then
    return getValue("8tparameters", '{}')
  elseif gridLength == 6 then
    return getValue("16tparameters", '{}')
  elseif gridLength == 5 then
    return getValue("quintupletparameters", '{}')
  else
    return nil
  end
end

return {
  deserializeTable = deserializeTable,
  getActiveMediaItem = getActiveMediaItem,
  getActiveMidiTake = getActiveMidiTake,
  getGridUnitLength = getGridUnitLength,
  getItemPPQ = getItemPPQ,
  getMediaItemEndPositionPPQ = getMediaItemEndPositionPPQ,
  getMediaItemStartPositionPPQ = getMediaItemStartPositionPPQ,
  getParametersForGridLength = getParametersForGridLength,
  getValue = getValue,
  getValuePersist = getValuePersist,
  map = map,
  print = print,
  requestUserConfiguration = requestUserConfiguration,
  serializeTable = serializeTable,
  setValue = setValue,
  setValuePersist = setValuePersist,
  speak = speak,
}