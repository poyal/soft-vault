-- Native-window mpv/IINA comparison. Measures decoder restart, not GUI latency.
local mp = require 'mp'
local utils = require 'mp.utils'
local options = require 'mp.options'
local cfg = {output = 'reference.json', seconds = 300, seeks = 30}
options.read_options(cfg, 'quality')
local report = {measurement = 'native command to playback-restart; no GUI event dispatch', files = {}}
local record, pending, started, sample_timer, watchdog
local function write()
    local f = assert(io.open(cfg.output, 'w'))
    f:write(utils.format_json(report))
    f:close()
end
local function snapshot()
    local out = {}
    for _, name in ipairs({'mpv-version', 'hwdec-current', 'video-codec',
        'container-fps', 'playback-time', 'frame-drop-count',
        'decoder-frame-drop-count', 'vo-delayed-frame-count', 'avsync',
        'paused-for-cache', 'demuxer-cache-duration', 'seeking', 'pause'}) do
        out[name] = mp.get_property_native(name)
    end
    return out
end
local function continuous()
    mp.set_property_bool('pause', true)
    pending = {kind = 'steady', target = 2, sent = mp.get_time()}
    mp.commandv('seek', 2, 'absolute+exact')
end
local function seek_next()
    local i = #record.seeks
    if i >= cfg.seeks then continuous(); return end
    mp.set_property_bool('pause', true)
    local duration = mp.get_property_number('duration')
    local target = duration * (.1 + ((i * 37) % 79) / 100)
    pending = {kind = 'seek', target = target, sent = mp.get_time()}
    mp.commandv('seek', target, 'absolute+exact')
end
-- IINA can asynchronously resume after its file-open UI work finishes. Keep
-- timed seeks paused; an advancing audio clock is not a paused-seek result.
mp.observe_property('pause', 'bool', function(_, paused)
    if paused == false and pending and pending.kind == 'seek' then
        mp.set_property_bool('pause', true)
    end
end)
mp.register_event('playback-restart', function()
    if not pending then return end
    local request = pending
    local pos = mp.get_property_number('playback-time', -1)
    local fps = mp.get_property_number('container-fps', 24)
    local vfr = string.find(record.file, '-vfr', 1, true)
    local tolerance = 1 / (vfr and 15 or math.max(1, fps)) + .004
    if math.abs(pos - request.target) > tolerance then return end
    pending = nil
    if request.kind == 'seek' then
        table.insert(record.seeks, {targetSeconds = request.target,
            nativeFrameReadyMs = (mp.get_time() - request.sent) * 1000,
            playbackTime = pos})
        mp.add_timeout(.03, seek_next)
    else
        mp.set_property_bool('pause', false)
        mp.add_timeout(1, function()
            started = mp.get_time()
            sample_timer = mp.add_periodic_timer(1, function()
                local sample = snapshot()
                sample.elapsedMs = (mp.get_time() - started) * 1000
                table.insert(record.playbackSamples, sample)
                if mp.get_time() - started >= cfg.seconds then
                    sample_timer:kill()
                    sample_timer = nil
                    record.completed = true
                    write()
                    if mp.get_property_number('playlist-pos') + 1 >= mp.get_property_number('playlist-count') then
                        mp.commandv('quit', 0)
                    else
                        mp.commandv('playlist-next', 'force')
                    end
                end
            end)
        end)
    end
end)
mp.register_event('file-loaded', function()
    record = {file = mp.get_property('filename'), initial = snapshot(), seeks = {}, playbackSamples = {}}
    table.insert(report.files, record)
    mp.set_property_number('volume', 0)
    mp.set_property_bool('pause', true)
    pending = nil
    mp.add_timeout(.5, seek_next)
end)
watchdog = mp.add_periodic_timer(1, function()
    if pending and pending.sent and mp.get_time() - pending.sent > 15 then
        record.error = 'native seek timed out'
        record.pendingTargetSeconds = pending.target
        record.failureSnapshot = snapshot()
        write()
        mp.commandv('quit', 2)
    end
end)
mp.register_event('shutdown', write)
