local _, _, section = reaper.get_action_context()

-- 今のセクションを調べる
local midi = section == 32060
local editor = midi and reaper.MIDIEditor_GetActive() or nil

if midi and not editor then return end

local actions = midi and {}
