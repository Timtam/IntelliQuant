-- fixing script path for correct require calls
local path = ({reaper.get_action_context()})[2]:match('^.+[\\//]')
package.path = path .. "?.lua"

local IntelliQuant = require('timtam_IntelliQuant')

local function main()

  local itemPPQ = IntelliQuant.getItemPPQ()

  local gridLengthPPQ = IntelliQuant.getGridUnitLength()

  local gridLength = itemPPQ / gridLengthPPQ

  local sValue

  if gridLength == 8 then
    sValue = IntelliQuant.getValue("32parameters", '{}')
  elseif gridLength == 4 then
    sValue = IntelliQuant.getValue("16parameters", '{}')
  elseif gridLength == 2 then
    sValue = IntelliQuant.getValue("8parameters", '{}')
  elseif gridLength == 1 then
    sValue = IntelliQuant.getValue("4parameters", '{}')
  elseif gridLength == 3 then
    sValue = IntelliQuant.getValue("8tparameters", '{}')
  elseif gridLength == 6 then
    sValue = IntelliQuant.getValue("16tparameters", '{}')
  elseif gridLength == 5 then
    sValue = IntelliQuant.getValue("quintupletparameters", '{}')
  else
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
  
  reaper.MIDI_DisableSort(take)
  math.randomseed(os.time())

  reaper.Undo_BeginBlock()

  local previousNoteStartPPQ = 0
  local previousOffset = 0

  while noteCount > 0 do
    local success, selected, muted, startPPQ, endPPQ, channel, pitch, velocity = reaper.MIDI_GetNote(take, 0)
    local offset = 0

    if startPPQ - previousNoteStartPPQ <= math.floor(tValue.flam * itemPPQ / 100) then
      offset = previousOffset
    else

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
    end

    reaper.MIDI_DeleteNote(take, 0)

    if offset == 0 then
      if previousAdjustmentWindow ~= nil and previousDetectionWindow ~= nil and startPPQ < previousDetectionWindow.max and startPPQ > previousAdjustmentWindow.max then
        offset = math.random(previousAdjustmentWindow.min, previousAdjustmentWindow.max) - startPPQ
      elseif nextDetectionWindow ~= nil and nextAdjustmentWindow ~= nil and startPPQ > nextDetectionWindow.min and startPPQ < nextAdjustmentWindow.min then
        offset = math.random(nextAdjustmentWindow.min, nextAdjustmentWindow.max) - startPPQ
      end
    end

    reaper.MIDI_InsertNote(take, selected, muted, startPPQ + offset, endPPQ + offset, channel, pitch, velocity, true)

    noteCount = noteCount - 1

    previousOffset = offset

  end

  reaper.MIDI_Sort(take)
  reaper.Undo_OnStateChange_Item(0, "IntelliQuant: quantize", IntelliQuant.getActiveMediaItem())
  reaper.Undo_EndBlock("IntelliQuant: quantize", 0)

end

main()