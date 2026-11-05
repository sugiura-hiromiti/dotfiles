-- Convert automatically sized tracks to their current displayed pixel
-- heights. Existing per-track overrides remain untouched.
-- This is not B_HEIGHTLOCK; ordinary vertical zoom stays available.
local project = 0
local updates = {}

for i = 0, reaper.CountTracks(project) - 1 do
  local track = reaper.GetTrack(project, i)
  if reaper.GetMediaTrackInfo_Value(track, "I_HEIGHTOVERRIDE") <= 0 then
    local height = reaper.GetMediaTrackInfo_Value(track, "I_TCPH")
    if height > 0 then
      updates[#updates + 1] = { track = track, height = height }
    end
  end
end

if #updates == 0 then return end

reaper.Undo_BeginBlock2(project)
for _, entry in ipairs(updates) do
  reaper.SetMediaTrackInfo_Value(entry.track, "I_HEIGHTOVERRIDE", entry.height)
end
reaper.TrackList_AdjustWindows(false)
reaper.Undo_EndBlock2(project, "Preserve current track heights", -1)
