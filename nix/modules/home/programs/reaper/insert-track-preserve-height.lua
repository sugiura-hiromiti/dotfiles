-- Use REAPER's native insert action, then preserve the new track's displayed
-- height so resizing the arrange view or opening a Docker does not scale it.
local project = 0
local existing = {}
for i = 0, reaper.CountTracks(project) - 1 do
  existing[reaper.GetTrack(project, i)] = true
end

reaper.Undo_BeginBlock2(project)
reaper.Main_OnCommand(40001, 0) -- Track: Insert new track
reaper.TrackList_AdjustWindows(false)

local changed = false
for i = 0, reaper.CountTracks(project) - 1 do
  local track = reaper.GetTrack(project, i)
  if not existing[track] then
    local height = reaper.GetMediaTrackInfo_Value(track, "I_TCPH")
    if height > 0 then
      reaper.SetMediaTrackInfo_Value(track, "I_HEIGHTOVERRIDE", height)
      changed = true
    end
  end
end

if changed then
  reaper.TrackList_AdjustWindows(false)
end
reaper.Undo_EndBlock2(project, "Insert track with preserved height", -1)
