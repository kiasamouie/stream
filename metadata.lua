local utils = require 'mp.utils'

mp.msg.info("Metadata script loaded")

local function current_entry_url()
    -- Use playlist entry’s original filename (usually the page URL)
    local pos = mp.get_property_number("playlist-pos", -1)
    local pl = mp.get_property_native("playlist")
    if pl and pos and pos >= 0 and pl[pos + 1] and pl[pos + 1].filename then
        return pl[pos + 1].filename
    end
    -- Fallback: extract URL from EDL
    local edl = mp.get_property("path") or ""
    local http_in_edl = edl:match("(https?://%S+)")
    return http_in_edl
end

local function update_metadata()
    local title = mp.get_property("media-title") or ""
    local url = current_entry_url()
    if not url or not url:match("^https?://") then
        mp.msg.warn("No usable URL for metadata")
        return
    end

    mp.msg.info("Fetching metadata via yt-dlp for " .. url)
    local res = utils.subprocess({
        args = {"yt-dlp", "-J", url},
        cancellable = false
    })
    if res.status ~= 0 then
        mp.msg.error("yt-dlp failed: " .. (res.error or "unknown"))
        return
    end

    local json, err = utils.parse_json(res.stdout)
    if not json then
        mp.msg.error("Failed to parse JSON: " .. tostring(err))
        return
    end

    -- Determine final title/artist
    local json_title    = json.title or title or "Unknown Title"
    local json_uploader = json.uploader or "Unknown Artist"

    -- Write nowplaying.txt as "<Artist> - <Title>"
    do
        local f = io.open("/opt/ytstream/assets/nowplaying.txt", "w")
        if f then
            f:write(string.format("%s - %s", json_uploader, json_title))
            f:close()
        else
            mp.msg.error("Failed to open nowplaying.txt for writing")
        end
    end

    -- Choose artwork thumbnail near 100x100
    if json.thumbnails and #json.thumbnails > 0 then
        local best_url = nil
        local best_size = nil

        -- pass 1: exact 100x100
        for _, thumb in ipairs(json.thumbnails) do
            if thumb.width == 100 or thumb.height == 100 then
                best_url = thumb.url
                best_size = thumb.width
                break
            end
        end

        -- pass 2: smallest >=100
        if not best_url then
            for _, thumb in ipairs(json.thumbnails) do
                if thumb.width >= 100 and (not best_size or thumb.width < best_size) then
                    best_url = thumb.url
                    best_size = thumb.width
                end
            end
        end

        -- pass 3: largest available
        if not best_url then
            for _, thumb in ipairs(json.thumbnails) do
                if not best_size or thumb.width > best_size then
                    best_url = thumb.url
                    best_size = thumb.width
                end
            end
        end

        if best_url then
            local tmp = "/opt/ytstream/assets/.artwork.tmp"
            utils.subprocess({ args = {"curl", "-fsSL", "-o", tmp, best_url} })
            if best_size ~= 100 then
                utils.subprocess({ args = {"mogrify", "-resize", "100x100", tmp} })
            end
            utils.subprocess({ args = {"mv", "-f", tmp, "/opt/ytstream/assets/artwork.jpg"} })
        else
            mp.msg.warn("No usable thumbnails found")
        end
    else
        mp.msg.warn("No thumbnails in yt-dlp JSON")
    end
end

mp.register_event("file-loaded", update_metadata)
