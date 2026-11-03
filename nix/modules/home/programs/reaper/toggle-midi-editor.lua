local midi_section = 32060
local open_editor = 40153
local close_editor = 2
local toggle_dock = 40018

local editor = reaper.MIDIEditor_GetActive()

-- editorが開いてる場合は閉じる
if editor then
	reaper.MIDIEditor_OnCommand(editor, close_editor)
	return
end

-- 選択されているmidi itemを見つける
local has_midi_item = false

-- open selected MIDI items in the built-in editor
for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
	local item = reaper.GetSelectedMediaItem(0, i)
	local take = reaper.GetActiveTake(item)
	if take and reaper.TakeIsMIDI(take) then
		has_midi_item = true
		break
	end
end

if not has_midi_item then return end

-- midi editorを開く
reaper.Main_OnCommand(open_editor, 0)
editor = reaper.MIDIEditor_GetActive()
if not editor then return end

-- editorがdockされているか確認
if reaper.GetToggleCommandStateEx(midi_section, toggle_dock) == 0 then
	reaper.MIDIEditor_OnCommand(editor, toggle_dock)
end
