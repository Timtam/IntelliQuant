-- fixing script path for correct require calls
local path = ({reaper.get_action_context()})[2]:match('^.+[\\//]')
package.path = path .. "?.lua"

local IntelliQuant = require('timtam_IntelliQuant')

local function main()

  local itemPPQ = IntelliQuant.getItemPPQ()

  local gridLengthPPQ = IntelliQuant.getGridUnitLength()

  local gridLength = itemPPQ / gridLengthPPQ

  local sValue = IntelliQuant.getParametersForGridLength(gridLength)

  if sValue == nil then
    IntelliQuant.speak("Unsupported grid length found, aborting.")
    return
  end

  if sValue == '{}' then
    IntelliQuant.speak("No configuration found for this grid length. Please run the appropriate action first.")
    return
  end

  local tValue = IntelliQuant.deserializeTable(sValue)

  if tValue.adjustment_lookahead == 0 and tValue.adjustment_lookbehind == 0 and tValue.detection_lookahead == 0 and tValue.detection_lookbehind == 0 then
    IntelliQuant.speak("All parameters for this grid length are set to 0, there is nothing to do here.")
    return
  end

  local take = IntelliQuant.getActiveMidiTake()
  local success, noteCount, _, _ = reaper.MIDI_CountEvts(take)

  if not success then
    IntelliQuant.speak("Unable to get amount of MIDI notes, aborting.")
    return
  end
  
  local itemStartPositionPPQ = IntelliQuant.getMediaItemStartPositionPPQ()
  local itemEndPositionPPQ = IntelliQuant.getMediaItemEndPositionPPQ()
  local onGrid = 0
  local offGrid = 0
  local lookaheadAdjustment = 0
  local lookbehindAdjustment = 0
  local lookaheadDetection = 0
  local lookbehindDetection = 0
  
  for i=0,noteCount-1 do
    local _, _, _, startPPQ, _, _, _, _ = reaper.MIDI_GetNote(take, i)

    local previousCenter = (startPPQ // gridLengthPPQ) * gridLengthPPQ
    local nextCenter = previousCenter + gridLengthPPQ

    local previousAdjustmentWindow = {
      min = previousCenter,
      max = previousCenter + math.floor(tValue.adjustment_lookahead * itemPPQ / 100)
    }

    if previousAdjustmentWindow.min < itemStartPositionPPQ and previousAdjustmentWindow.max >= itemStartPositionPPQ then
      previousAdjustmentWindow.min = itemStartPositionPPQ
    elseif previousAdjustmentWindow.min <= itemEndPositionPPQ and previousAdjustmentWindow.max > itemEndPositionPPQ then
      previousAdjustmentWindow.max = itemEndPositionPPQ
    elseif (previousAdjustmentWindow.min < itemStartPositionPPQ) and (previousAdjustmentWindow.max < itemStartPositionPPQ or previousAdjustmentWindow.max > itemEndPositionPPQ) then
      previousAdjustmentWindow = nil
    end

    local nextAdjustmentWindow = {
      min = nextCenter - math.floor(tValue.adjustment_lookbehind * itemPPQ / 100),
      max = nextCenter
    }

    if nextAdjustmentWindow.min < itemStartPositionPPQ and nextAdjustmentWindow.max >= itemStartPositionPPQ then
      nextAdjustmentWindow.min = itemStartPositionPPQ
    elseif nextAdjustmentWindow.min <= itemEndPositionPPQ and nextAdjustmentWindow.max > itemEndPositionPPQ then
      nextAdjustmentWindow.max = itemEndPositionPPQ
    elseif (nextAdjustmentWindow.min < itemStartPositionPPQ) and (nextAdjustmentWindow.max < itemStartPositionPPQ or nextAdjustmentWindow.max > itemEndPositionPPQ) then
      nextAdjustmentWindow = nil
    end

    local previousDetectionWindow = {
      min = previousCenter,
      max = previousCenter + math.floor(tValue.detection_lookahead * itemPPQ / 100)
    }

    if previousDetectionWindow.min < itemStartPositionPPQ and previousDetectionWindow.max >= itemStartPositionPPQ then
      previousDetectionWindow.min = itemStartPositionPPQ
    elseif previousDetectionWindow.min <= itemEndPositionPPQ and previousDetectionWindow.max > itemEndPositionPPQ then
      previousDetectionWindow.max = itemEndPositionPPQ
    elseif (previousDetectionWindow.min < itemStartPositionPPQ) and (previousDetectionWindow.max < itemStartPositionPPQ or previousDetectionWindow.max > itemEndPositionPPQ) then
      previousDetectionWindow = nil
    end

    local nextDetectionWindow = {
      min = nextCenter - math.floor(tValue.detection_lookbehind * itemPPQ / 100),
      max = nextCenter
    }

    if nextDetectionWindow.min < itemStartPositionPPQ and nextDetectionWindow.max >= itemStartPositionPPQ then
      nextDetectionWindow.min = itemStartPositionPPQ
    elseif nextDetectionWindow.min <= itemEndPositionPPQ and nextDetectionWindow.max > itemEndPositionPPQ then
      nextDetectionWindow.max = itemEndPositionPPQ
    elseif (nextDetectionWindow.min < itemStartPositionPPQ) and (nextDetectionWindow.max < itemStartPositionPPQ or nextDetectionWindow.max > itemEndPositionPPQ) then
      nextDetectionWindow = nil
    end

    if previousAdjustmentWindow ~= nil and previousDetectionWindow ~= nil and startPPQ < previousDetectionWindow.max and startPPQ > previousAdjustmentWindow.max then
      lookaheadDetection = lookaheadDetection + 1
    elseif nextDetectionWindow ~= nil and nextAdjustmentWindow ~= nil and startPPQ > nextDetectionWindow.min and startPPQ < nextAdjustmentWindow.min then
      lookbehindDetection = lookbehindDetection + 1
    elseif nextAdjustmentWindow ~= nil and startPPQ > nextAdjustmentWindow.min and startPPQ < nextAdjustmentWindow.max then
      lookbehindAdjustment = lookbehindAdjustment + 1
    elseif previousAdjustmentWindow ~= nil and startPPQ > previousAdjustmentWindow.min and startPPQ < previousAdjustmentWindow.max then
      lookaheadAdjustment = lookaheadAdjustment + 1
    elseif startPPQ == previousCenter then
      onGrid = onGrid + 1
    else
      offGrid = offGrid + 1
    end
  end

  local msg = tostring(noteCount) .. " notes selected.\n"
  msg = msg .. tostring(onGrid) .. " notes on grid lines.\n"
  msg = msg .. tostring(lookbehindAdjustment + lookaheadAdjustment) .. " notes are within the adjustment window (" .. tostring(lookaheadAdjustment) .. " ahead, " .. tostring(lookbehindAdjustment) .. " behind).\n"
  msg = msg .. tostring(lookbehindDetection + lookaheadDetection) .. " notes within the detection window (" .. tostring(lookaheadDetection) .. " ahead, " .. tostring(lookbehindDetection) .. " behind).\n"
  msg = msg .. tostring(offGrid) .. " notes far out (as in, we can't be sure where these were intended to be)."

  IntelliQuant.speak(msg)

end

main()