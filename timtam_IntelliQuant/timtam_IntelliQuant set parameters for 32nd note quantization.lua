-- fixing script path for correct require calls
local path = ({reaper.get_action_context()})[2]:match('^.+[\\//]')
package.path = path .. "?.lua"

local IntelliQuant = require('timtam_IntelliQuant')

IntelliQuant.requestUserConfiguration("32parameters", "Parameters for 1/32 note quantization")
