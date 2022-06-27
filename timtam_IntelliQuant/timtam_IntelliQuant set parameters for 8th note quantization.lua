-- fixing script path for correct require calls
local path = ({reaper.get_action_context()})[2]:match('^.+[\\//]')
package.path = path .. "?.lua"

local IntelliQuant = require('timtam_IntelliQuant')

IntelliQuant.requestUserConfiguration("8parameters", "Parameters for 1/8 note quantization")
