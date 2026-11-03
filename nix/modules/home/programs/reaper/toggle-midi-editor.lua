local editor = reaper.MIDIEditor_GetActive()

if editor then
	reaper.MIDIEditor_OnCommand(editor, 2)
	return
end

-- open selected MIDI items in the built-in editor
for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
	local item = reaper.GetSelectedMediaItem(0, i)
	local take = reaper.GetActiveTake(item)
	if take and reaper.TakeIsMIDI(take) then
		reaper.Main_OnCommand(40153, 0)
		return
	end
end
