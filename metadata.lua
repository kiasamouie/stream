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

local function sanitize(text)
    if not text or text == "" then return text end

    -- Normalize spacing and remove bracketed content
    text = text:gsub("%b[]", "")
    text = text:gsub("%b()", "")

    -- Remove problematic punctuation
    local chars = {"'", ":", ",", ";", "=", "#", "/", '"', "\\"}
    for _, ch in ipairs(chars) do
        text = text:gsub(ch, "")
    end

    -- Remove emojis and extended unicode symbols
    text = text:gsub("[%z\1-\127\194-\244][\128-\191]*", function(char)
        return char:match("^[ %w%p]+$") and char or ""
    end)

    -- Collapse whitespace and trim - _ and spaces
    text = text:gsub("%s+", " "):gsub("^[%s%-_]+", ""):gsub("[%s%-_]+$", "")

    return text
end

-- Select the most reliable thumbnail (SoundCloud structure aware)
local function select_best_thumbnail(thumbnails)
    if not thumbnails or #thumbnails == 0 then return nil end

    local preferred_ids = {"t300x300", "large", "t500x500", "original"}

    -- Pass 1: Look for named IDs like t300x300 or large
    for _, pref in ipairs(preferred_ids) do
        for _, thumb in ipairs(thumbnails) do
            if thumb.id == pref or (thumb.url and thumb.url:find(pref, 1, true)) then
                return thumb.url, thumb.width or 300
            end
        end
    end

    -- Pass 2: fallback to the largest available width
    local best = thumbnails[1]
    for _, t in ipairs(thumbnails) do
        if t.width and (not best.width or t.width > best.width) then
            best = t
        end
    end

    return best.url, best.width or 300
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

    -- Handle both playlist entries and single tracks
    local entry = json
    if json.entries and #json.entries > 0 then
        entry = json.entries[1]
    end

    local json_title    = entry.title or title or "Unknown Title"
    local json_uploader = entry.uploader or "Unknown Artist"

    -- ✅ Apply sanitization to the song title only
    json_title = sanitize(json_title)

    -- Write nowplaying.txt as "<Artist> - <Title>"
    do
        local f = io.open("/opt/ytstream/assets/nowplaying.txt", "w")
        if f then
            f:write(string.format("%s\n%s", json_uploader, json_title))
            f:close()
        else
            mp.msg.error("Failed to open nowplaying.txt for writing")
        end
    end

    -- Choose artwork thumbnail near 200x200
    if entry.thumbnails and #entry.thumbnails > 0 then
        local best_url, best_size = select_best_thumbnail(entry.thumbnails)
        if best_url then
            local tmp = "/opt/ytstream/assets/.artwork.tmp"
            utils.subprocess({ args = {"curl", "-fsSL", "-o", tmp, best_url} })

            -- Resize only if larger than 200px
            if best_size and best_size > 200 then
                utils.subprocess({ args = {"mogrify", "-resize", "150x150", tmp} })
            end

            utils.subprocess({ args = {"mv", "-f", tmp, "/opt/ytstream/assets/artwork.jpg"} })
        else
            mp.msg.warn("No usable thumbnails found")
        end
    else
        mp.msg.warn("No thumbnails in yt-dlp JSON — generating blank image")
        utils.subprocess({ args = {"convert", "-size", "200x200", "xc:black", "/opt/ytstream/assets/artwork.jpg"} })
    end
end

mp.register_event("file-loaded", update_metadata)
