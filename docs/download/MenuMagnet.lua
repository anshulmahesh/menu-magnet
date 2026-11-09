------------------------------------------------------------
-- MENU MAGNET v13
--
-- Stable / low-UI version with fixed scroll accumulation + submenu recovery.
--
-- IMPORTANT:
--   ALL USER CONTROLS ARE IN THIS CONFIG BLOCK.
--   Edit them, save the file, then reload Hammerspoon.
--
-- Hotkeys (editable below):
--   Ctrl + Alt + Cmd + P  -> open THIS Lua file
--   Ctrl + Alt + Cmd + M  -> master on/off
--   Ctrl + Alt + Cmd + R  -> reload Hammerspoon
------------------------------------------------------------

local CONFIG = {
    --------------------------------------------------------
    -- MASTER
    --------------------------------------------------------
    enabled = true,

    -- Menu types
    rightClickMenus = true,
    menuBarMenus = true,       -- File / Edit / View / Develop / etc.

    --------------------------------------------------------
    -- MAGNET FEEL
    --------------------------------------------------------

    -- Finger travel before one magnetic detent.
    -- Lower = more sensitive.
    scrollThreshold = 15,

    -- v13: scroll accumulation is preserved while the pointer remains on
    -- the same row. This fixes the v12 "first snap then stuck" regression.

    -- Faster gestures may move more than one row.
    velocityScrolling = true,
    velocitySensitivity = 45,  -- 0..100
    maxJump = 3,               -- max rows per fast flick

    -- Delay between rows when a flick requests several rows.
    stepIntervalMs = 44,

    -- Reverse vertical scroll direction.
    invertScroll = true,

    -- IMPORTANT FOR TOP MENUS:
    -- Horizontal scroll is ALWAYS swallowed while Menu Magnet owns a
    -- menu. This prevents diagonal two-finger movement from changing
    -- File -> Edit -> View accidentally.
    ignoreHorizontalScroll = true,

    -- Keep pointer X where it already is whenever it is safely inside
    -- the current menu row. This avoids unnecessary sideways movement.
    lockPointerX = true,

    -- 0 = instant vertical snap (most reliable).
    -- 1..6 = number of tiny interpolation frames.
    verticalSmoothingFrames = 0,

    --------------------------------------------------------
    -- RIGHT-CLICK MODE
    --------------------------------------------------------

    -- false = right-click normally, release, then scroll.
    -- true  = keep secondary click held while scrolling.
    holdSecondaryClick = false,

    --------------------------------------------------------
    -- SUBMENUS
    --------------------------------------------------------

    -- Normal left click on a menu row:
    -- if macOS opens a submenu, Menu Magnet automatically follows it.
    clickEntersSubmenu = true,

    -- TWO-FINGER CLICK / SECONDARY CLICK while a menu is already open:
    -- if the row owns a submenu, treat the gesture as "go deeper" instead
    -- of starting a brand-new context menu. This is separate from ordinary
    -- two-finger scrolling.
    twoFingerClickEntersSubmenu = true,

    -- Safety guard: only convert the two-finger/secondary click when AX
    -- reports a submenu (or one is already visibly open). This prevents a
    -- secondary click from accidentally executing an ordinary command.
    twoFingerSubmenuOnly = true,

    -- Maximum pointer drift from secondary-button down to up.
    twoFingerClickMaxMovementPx = 12,

    -- EDGE ESCAPE (recommended replacement for unreliable 3-finger taps):
    -- Reach the first/last row of a submenu, lift your fingers, then scroll
    -- again in the SAME direction. Menu Magnet jumps back to the ROOT menu
    -- and selects the previous/next root item in that direction.
    edgeEscapeToRoot = true,

    -- A new scroll gesture is recognised after this quiet gap.
    -- Raise this if one long gesture escapes too easily; lower it if you need
    -- an exaggerated pause before the second scroll is recognised.
    edgeEscapeGestureGap = 0.085,

    -- After returning to root, advance one root row in the same direction.
    edgeEscapeAdvanceRoot = true,

    -- Legacy/experimental 3-finger back is retained but OFF by default.
    -- The edge escape above is much more deterministic in macOS menus.
    threeFingerBack = false,
    threeFingerBackMode = "root",
    threeFingerMaxDuration = 0.48,
    threeFingerMaxMovement = 0.035,
    consumeThreeFingerTap = true,
    middleClickAlsoBack = false,

    --------------------------------------------------------
    -- HAPTIC / SOUND FEEDBACK
    --------------------------------------------------------

    hapticEnabled = true,
    hapticWaveform = 1,        -- mactic waveform 1..6

    -- Sound is a FALLBACK: it plays only when haptic feedback is off
    -- or mactic is unavailable. It does not play on top of haptics.
    soundFallbackEnabled = true,
    soundName = "Tink",       -- falls back to Pop/Purr if unavailable
    soundVolume = 7,           -- 0..30, deliberately subtle

    --------------------------------------------------------
    -- MENU DETECTION
    --------------------------------------------------------

    -- File/Edit detection is retried after the native click. v12 also
    -- performs lazy recovery on the FIRST scroll event if detection was
    -- missed, which makes top-menu scrolling much more consistent.
    detectionDelay = 0.015,
    detectionRetries = 34,
    detectionRetryDelay = 0.020,
    menuIntentLifetime = 3.0,

    -- Expanded File/Edit/View hit area. This deliberately treats the entire
    -- visible menu-bar band (plus a little padding) as a valid click target,
    -- so clicks at the extreme top edge of the screen are still detected.
    menuBarHitPaddingX = 8,
    menuBarHitPaddingTop = 18,
    menuBarHitPaddingBottom = 18,
    menuBarFallbackHeight = 48,

    --------------------------------------------------------
    -- MENU BAR ITEM
    --------------------------------------------------------

    -- Keep this lightweight. No WebView/settings window is created.
    showMenuBarItem = false,
    menuBarTitle = "⇵",

    --------------------------------------------------------
    -- HOTKEYS
    --------------------------------------------------------

    openConfigHotkey = { mods = { "ctrl", "alt", "cmd" }, key = "P" },
    toggleHotkey     = { mods = { "ctrl", "alt", "cmd" }, key = "M" },
    reloadHotkey     = { mods = { "ctrl", "alt", "cmd" }, key = "R" },

    -- Command used by the open-config hotkey.
    -- Default opens in the macOS text editor associated with text files.
    -- Example for VS Code:
    -- editorCommand = [[/usr/bin/open -a "Visual Studio Code"]],
    editorCommand = [[/usr/bin/open -t]],

    --------------------------------------------------------
    -- DIAGNOSTICS
    --------------------------------------------------------

    debugAX = false,
    showAlerts = true,
}

------------------------------------------------------------
-- END USER CONFIG
-- Everything below is engine code.
------------------------------------------------------------

hs.menuIcon(false)

local ax       = hs.axuielement
local event    = hs.eventtap.event
local eventtap = hs.eventtap
local timer    = hs.timer
local sound    = hs.sound
local props    = event.properties
local types    = event.types

------------------------------------------------------------
-- SCRIPT PATH / OPEN CONFIG
------------------------------------------------------------

local function currentScriptPath()
    local src = debug.getinfo(1, "S").source or ""
    if src:sub(1, 1) == "@" then src = src:sub(2) end
    return src
end

local SCRIPT_PATH = currentScriptPath()

local function openConfigFile()
    if SCRIPT_PATH == "" then
        hs.alert.show("Menu Magnet: could not determine Lua file path")
        return
    end

    local command = tostring(CONFIG.editorCommand or "/usr/bin/open -t")
        .. " " .. string.format("%q", SCRIPT_PATH)

    local output, status = hs.execute(command, false)
    if not status then
        print("[MenuMagnet] open config failed:", output or "unknown error")
        hs.alert.show("Menu Magnet: could not open Lua file")
    end
end

------------------------------------------------------------
-- GENERAL HELPERS
------------------------------------------------------------

local function clamp(v, lo, hi)
    v = tonumber(v) or lo
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function nowSeconds()
    return hs.timer.absoluteTime() / 1000000000
end

local function safeCall(fn, fallback)
    local ok, value = pcall(fn)
    if ok then return value end
    return fallback
end

local function roleOf(el)
    if not el then return nil end
    return safeCall(function() return el:attributeValue("AXRole") end, nil)
end

local function titleOf(el)
    if not el then return "" end
    return tostring(safeCall(function()
        return el:attributeValue("AXTitle")
            or el:attributeValue("AXDescription")
            or ""
    end, "") or "")
end

local function frameOf(el)
    if not el then return nil end

    local f = safeCall(function() return el:attributeValue("AXFrame") end, nil)
    if f and f.x and f.y and f.w and f.h then return f end

    local p = safeCall(function() return el:attributeValue("AXPosition") end, nil)
    local s = safeCall(function() return el:attributeValue("AXSize") end, nil)
    if p and s then
        return { x = p.x, y = p.y, w = s.w, h = s.h }
    end

    return nil
end

local function childrenOf(el)
    if not el then return {} end
    local c = safeCall(function() return el:attributeValue("AXChildren") end, {})
    return type(c) == "table" and c or {}
end

local function isValid(el)
    if not el then return false end
    return safeCall(function() return el:isValid() end, false) == true
end

local function elementAt(point)
    if not point then return nil end
    return safeCall(function() return ax.systemElementAtPosition(point) end, nil)
end

local function findAncestorRole(el, wanted)
    if not el then return nil end
    if roleOf(el) == wanted then return el end

    local path = safeCall(function() return el:path() end, nil)
    if not path then return nil end

    for i = #path, 1, -1 do
        if roleOf(path[i]) == wanted then return path[i] end
    end

    return nil
end

local function findDescendantRole(root, wanted, maxDepth)
    maxDepth = maxDepth or 5
    local seen = {}

    local function walk(node, depth)
        if not node or depth > maxDepth then return nil end

        local key = tostring(node)
        if seen[key] then return nil end
        seen[key] = true

        if roleOf(node) == wanted then return node end

        for _, child in ipairs(childrenOf(node)) do
            local result = walk(child, depth + 1)
            if result then return result end
        end

        return nil
    end

    return walk(root, 0)
end

local function debugAX(...)
    if CONFIG.debugAX then print("[MenuMagnet AX]", ...) end
end

------------------------------------------------------------
-- FEEDBACK
------------------------------------------------------------

local MACTIC_PATH = nil
for _, path in ipairs({
    "/opt/homebrew/bin/mactic",
    "/usr/local/bin/mactic",
}) do
    if hs.fs.attributes(path) then
        MACTIC_PATH = path
        break
    end
end

local function playHaptic(force)
    if (not force and not CONFIG.hapticEnabled) or not MACTIC_PATH then
        return false
    end

    local waveform = tostring(math.floor(clamp(CONFIG.hapticWaveform, 1, 6)))
    local task = hs.task.new(MACTIC_PATH, nil, { "-w", waveform })

    if task then
        task:start()
        return true
    end

    return false
end

local SUBTLE_SOUND = nil
local SUBTLE_SOUND_NAME = nil

local soundCandidates = {
    CONFIG.soundName,
    "Tink",
    "Pop",
    "Purr",
}

for _, name in ipairs(soundCandidates) do
    if name and name ~= "" then
        local candidate = sound.getByName(name)
        if candidate then
            SUBTLE_SOUND = candidate
            SUBTLE_SOUND_NAME = name
            pcall(function() candidate:stopOnReload(true) end)
            break
        end
    end
end

local function playSubtleSound(force)
    if (not force and not CONFIG.soundFallbackEnabled) or not SUBTLE_SOUND then
        return false
    end

    local volume = clamp(CONFIG.soundVolume, 0, 30) / 100

    pcall(function()
        SUBTLE_SOUND:stop()
        SUBTLE_SOUND:volume(volume)
        SUBTLE_SOUND:play()
    end)

    return true
end

local function playFeedback()
    if CONFIG.hapticEnabled and MACTIC_PATH then
        if playHaptic(true) then return end
    end

    if CONFIG.soundFallbackEnabled then
        playSubtleSound(false)
    end
end

------------------------------------------------------------
-- MENU ITEM READING
------------------------------------------------------------

local function buildMenuItems(menu)
    local result = {}

    for _, child in ipairs(childrenOf(menu)) do
        if roleOf(child) == "AXMenuItem" then
            local enabled = safeCall(function()
                return child:attributeValue("AXEnabled")
            end, true)

            local f = frameOf(child)
            local title = titleOf(child)

            if enabled ~= false and f and f.h > 3 and title ~= "" then
                table.insert(result, {
                    element = child,
                    frame = f,
                    title = title,
                })
            end
        end
    end

    table.sort(result, function(a, b)
        return a.frame.y < b.frame.y
    end)

    return result
end

local function itemIndexAtPoint(items, point)
    if not point then return nil end

    for i, item in ipairs(items) do
        local f = item.frame
        if point.x >= f.x and point.x <= f.x + f.w
            and point.y >= f.y and point.y <= f.y + f.h then
            return i
        end
    end

    return nil
end

local function nearestItemIndex(items, point)
    if not point then return (#items > 0) and 1 or nil end

    local bestIndex = nil
    local bestDistance = math.huge

    for i, item in ipairs(items) do
        local cy = item.frame.y + item.frame.h * 0.5
        local distance = math.abs(cy - point.y)

        if distance < bestDistance then
            bestDistance = distance
            bestIndex = i
        end
    end

    return bestIndex
end

------------------------------------------------------------
-- MENU DETECTORS
------------------------------------------------------------

local function findMenuFromElement(el)
    return findAncestorRole(el, "AXMenu")
end

local function findContextMenu(point)
    local probes = {
        { x = point.x,      y = point.y },
        { x = point.x + 4,  y = point.y + 4 },
        { x = point.x + 10, y = point.y + 8 },
        { x = point.x + 8,  y = point.y + 16 },
        { x = point.x + 20, y = point.y + 20 },
        { x = point.x - 5,  y = point.y + 8 },
    }

    for _, probe in ipairs(probes) do
        local menu = findMenuFromElement(elementAt(probe))
        if menu and #buildMenuItems(menu) > 0 then return menu end
    end

    return nil
end

local function frontmostApplicationAX()
    local app = hs.application.frontmostApplication()
    if not app then return nil end
    return safeCall(function() return ax.applicationElement(app) end, nil)
end

local function findFrontmostMenuBar()
    local appAX = frontmostApplicationAX()
    if not appAX then return nil end

    for _, child in ipairs(childrenOf(appAX)) do
        if roleOf(child) == "AXMenuBar" then return child end
    end

    return findDescendantRole(appAX, "AXMenuBar", 3)
end

local function expandedMenuBarItemAtPoint(point)
    if not point then return nil end

    local menuBar = findFrontmostMenuBar()
    if not menuBar then return nil end

    local menuBarFrame = frameOf(menuBar)
    local xPad = tonumber(CONFIG.menuBarHitPaddingX) or 8
    local topPad = tonumber(CONFIG.menuBarHitPaddingTop) or 18
    local bottomPad = tonumber(CONFIG.menuBarHitPaddingBottom) or 18
    local fallbackHeight = tonumber(CONFIG.menuBarFallbackHeight) or 48

    local yInsideBand = point.y >= -topPad and point.y <= fallbackHeight + bottomPad
    if menuBarFrame then
        yInsideBand = point.y >= menuBarFrame.y - topPad
            and point.y <= menuBarFrame.y + menuBarFrame.h + bottomPad
    end

    if not yInsideBand then return nil end

    local best = nil
    local bestDistance = math.huge

    for _, child in ipairs(childrenOf(menuBar)) do
        if roleOf(child) == "AXMenuBarItem" then
            local f = frameOf(child)
            if f
                and point.x >= f.x - xPad
                and point.x <= f.x + f.w + xPad then
                local cx = f.x + f.w * 0.5
                local distance = math.abs(point.x - cx)
                if distance < bestDistance then
                    best = child
                    bestDistance = distance
                end
            end
        end
    end

    return best
end

local function menuBarItemAtPoint(point)
    local el = elementAt(point)
    if roleOf(el) == "AXMenuBarItem" then return el end

    local ancestor = findAncestorRole(el, "AXMenuBarItem")
    if ancestor then return ancestor end

    -- At the very top screen edge macOS can return no useful AX element.
    -- Fall back to the menu bar's item frames and match mainly by X.
    return expandedMenuBarItemAtPoint(point)
end

local function matchingMenuBarItem(source, clickPoint)
    if source and isValid(source) then return source end

    local menuBar = findFrontmostMenuBar()
    if not menuBar then return nil end

    local sourceTitle = source and titleOf(source) or ""

    for _, child in ipairs(childrenOf(menuBar)) do
        if roleOf(child) == "AXMenuBarItem"
            and sourceTitle ~= ""
            and titleOf(child) == sourceTitle then
            return child
        end
    end

    return expandedMenuBarItemAtPoint(clickPoint)
end

local function menuFromMenuBarItem(item)
    if not item or not isValid(item) then return nil end

    for _, child in ipairs(childrenOf(item)) do
        if roleOf(child) == "AXMenu" then
            local f = frameOf(child)
            if f and f.h > 5 and #buildMenuItems(child) > 0 then
                return child
            end
        end
    end

    local deep = findDescendantRole(item, "AXMenu", 5)
    if deep then
        local f = frameOf(deep)
        if f and f.h > 5 and #buildMenuItems(deep) > 0 then
            return deep
        end
    end

    return nil
end

local function menuByProbe(item, clickPoint)
    local probes = {}
    local f = frameOf(item)

    if f then
        local midX = f.x + f.w * 0.5
        table.insert(probes, { x = midX, y = f.y + f.h + 2 })
        table.insert(probes, { x = midX, y = f.y + f.h + 10 })
        table.insert(probes, { x = midX, y = f.y + f.h + 22 })
        table.insert(probes, { x = midX, y = f.y + f.h + 38 })
        table.insert(probes, { x = midX, y = f.y + f.h + 58 })
        table.insert(probes, { x = f.x + 8, y = f.y + f.h + 78 })
        table.insert(probes, { x = f.x + f.w - 8, y = f.y + f.h + 96 })
    end

    if clickPoint then
        table.insert(probes, { x = clickPoint.x,      y = clickPoint.y + 18 })
        table.insert(probes, { x = clickPoint.x,      y = clickPoint.y + 32 })
        table.insert(probes, { x = clickPoint.x + 4,  y = clickPoint.y + 48 })
        table.insert(probes, { x = clickPoint.x + 8,  y = clickPoint.y + 68 })
        table.insert(probes, { x = clickPoint.x + 12, y = clickPoint.y + 92 })
    end

    table.insert(probes, hs.mouse.absolutePosition())

    for _, probe in ipairs(probes) do
        local menu = findAncestorRole(elementAt(probe), "AXMenu")
        if menu then
            local mf = frameOf(menu)
            if mf and mf.h > 5 and #buildMenuItems(menu) > 0 then
                return menu
            end
        end
    end

    return nil
end

local function scanFrontmostAppForVisibleMenu(referencePoint)
    local appAX = frontmostApplicationAX()
    if not appAX then return nil end

    local seen = {}
    local candidates = {}

    local function walk(node, depth)
        if not node or depth > 6 then return end

        local key = tostring(node)
        if seen[key] then return end
        seen[key] = true

        if roleOf(node) == "AXMenu" then
            local f = frameOf(node)
            local items = f and buildMenuItems(node) or {}

            if f and f.h > 8 and #items > 0 then
                local score = 0

                if referencePoint then
                    local centerX = f.x + f.w * 0.5
                    score = math.abs(centerX - referencePoint.x)

                    if referencePoint.x >= f.x and referencePoint.x <= f.x + f.w then
                        score = score - 300
                    end
                end

                -- Top-level dropdowns are usually near the top of screen.
                score = score + math.max(0, f.y) * 0.02

                table.insert(candidates, {
                    menu = node,
                    score = score,
                })
            end
        end

        for _, child in ipairs(childrenOf(node)) do
            walk(child, depth + 1)
        end
    end

    walk(appAX, 0)

    table.sort(candidates, function(a, b)
        return a.score < b.score
    end)

    return candidates[1] and candidates[1].menu or nil
end

local function findMenuBarMenu(source, clickPoint, allowFullScan)
    local item = matchingMenuBarItem(source, clickPoint)

    local menu = menuFromMenuBarItem(item)
    if menu then
        debugAX("menu from AXMenuBarItem", item and titleOf(item) or "?")
        return menu, item
    end

    menu = menuByProbe(item, clickPoint)
    if menu then
        debugAX("menu from probe", item and titleOf(item) or "?")
        return menu, item
    end

    if allowFullScan then
        menu = scanFrontmostAppForVisibleMenu(clickPoint or hs.mouse.absolutePosition())
        if menu then
            debugAX("menu from AX app scan")
            return menu, item
        end
    end

    return nil, item
end

------------------------------------------------------------
-- SUBMENU HELPERS
------------------------------------------------------------

local function submenuChildOfMenuItem(element)
    if not element or not isValid(element) then return nil end

    for _, child in ipairs(childrenOf(element)) do
        if roleOf(child) == "AXMenu" then return child end
    end

    return findDescendantRole(element, "AXMenu", 4)
end

local function visibleSubmenuNearItem(item, parentMenu)
    if not item then return nil end

    local direct = submenuChildOfMenuItem(item.element)
    if direct and direct ~= parentMenu then
        local f = frameOf(direct)
        if f and f.h > 5 and #buildMenuItems(direct) > 0 then
            return direct
        end
    end

    local f = item.frame
    if not f then return nil end

    local cy = f.y + f.h * 0.5
    local probes = {
        { x = f.x + f.w + 8,  y = cy },
        { x = f.x + f.w + 26, y = cy },
        { x = f.x + f.w + 8,  y = cy + 12 },
        { x = f.x - 8,        y = cy },
        { x = f.x - 26,       y = cy },
    }

    for _, probe in ipairs(probes) do
        local menu = findAncestorRole(elementAt(probe), "AXMenu")
        if menu and menu ~= parentMenu then
            local mf = frameOf(menu)
            if mf and mf.h > 5 and #buildMenuItems(menu) > 0 then
                return menu
            end
        end
    end

    return nil
end

------------------------------------------------------------
-- ENGINE STATE
------------------------------------------------------------

local state = {
    pending = false,
    active = false,
    rightHeld = false,

    kind = nil,            -- "context" or "menubar"
    source = nil,          -- AXMenuBarItem for top menus
    menu = nil,
    items = {},
    index = nil,
    hasSnapped = false,

    clickPoint = nil,
    scrollAccumulator = 0,
    smoothedVelocity = 0,
    lastScrollTimestamp = nil,

    stepQueue = 0,
    stepTimer = nil,
    detectionTimer = nil,
    submenuTimer = nil,

    generation = 0,
    submenuGeneration = 0,

    menuStack = {},

    -- Edge-escape state. The edge is armed when a submenu reaches its first
    -- or last row. Only a NEW scroll gesture in the same direction escapes.
    edgeArmedDirection = nil,
    edgeArmedMenu = nil,
    edgeArmedGestureSerial = nil,
    scrollGestureSerial = 0,
    lastPhysicalScrollAt = nil,

    -- Used for lazy first-scroll recovery when AX did not expose the
    -- File/Edit dropdown quickly enough after the original click.
    lastMenuBarIntent = nil,

    -- Track a secondary/two-finger click that began inside the open menu.
    twoFingerMenuClick = nil,
}

local gestureState = {
    armed = false,
    startedAt = 0,
    starts = {},
    movedTooFar = false,
}

local MenuMagnetTap = nil
local menuBar = nil
local pointerTimer = nil

------------------------------------------------------------
-- POINTER MOVEMENT
------------------------------------------------------------

local MAGIC_EVENT_ID = 0x4D4D563D -- "MMV13"

local function cancelPointerAnimation()
    if pointerTimer then
        pointerTimer:stop()
        pointerTimer = nil
    end
end

local function postPointer(point, dragMode)
    local movementType = dragMode and types.rightMouseDragged or types.mouseMoved
    local e = event.newMouseEvent(movementType, point)
    e:setProperty(props.eventSourceUserData, MAGIC_EVENT_ID)
    e:post()
end

local function safeXForItem(item, currentX)
    local f = item.frame
    local margin = math.min(12, math.max(3, f.w * 0.08))
    local left = f.x + margin
    local right = f.x + f.w - margin

    if not CONFIG.lockPointerX then
        return f.x + f.w * 0.5
    end

    if currentX >= left and currentX <= right then
        return currentX
    end

    -- Prefer a point near the left side instead of the geometric centre.
    -- This minimizes sideways travel and avoids crossing neighbouring
    -- top-menu titles before the pointer has moved down into the menu.
    return math.min(right, left + math.min(22, f.w * 0.20))
end

local function movePointerToItem(item, dragMode)
    if not item then return end
    cancelPointerAnimation()

    local current = hs.mouse.absolutePosition()
    local targetX = safeXForItem(item, current.x)
    local targetY = item.frame.y + item.frame.h * 0.5

    -- Critical top-menu safety rule:
    -- Move DOWN first while preserving the current X. Only after the
    -- pointer is below the menu bar do we correct X. This prevents a
    -- magnetic snap from sweeping across File -> Edit -> View.
    if state.kind == "menubar" and current.y < item.frame.y then
        postPointer({ x = current.x, y = targetY }, dragMode)
        current = { x = current.x, y = targetY }
    end

    if math.abs(targetX - current.x) > 0.5 then
        postPointer({ x = targetX, y = current.y }, dragMode)
        current.x = targetX
    end

    local frames = math.floor(clamp(CONFIG.verticalSmoothingFrames, 0, 6))

    if frames <= 0 or math.abs(targetY - current.y) < 0.5 then
        postPointer({ x = targetX, y = targetY }, dragMode)
        return
    end

    local startY = current.y
    local step = 0

    pointerTimer = timer.doEvery(0.008, function()
        step = step + 1
        local t = step / frames
        if t > 1 then t = 1 end
        local eased = 1 - (1 - t) * (1 - t)

        postPointer({
            x = targetX,
            y = startY + (targetY - startY) * eased,
        }, dragMode)

        if step >= frames then
            cancelPointerAnimation()
        end
    end)
end

------------------------------------------------------------
-- TIMERS / RESET
------------------------------------------------------------

local function stopStepTimer()
    if state.stepTimer then
        state.stepTimer:stop()
        state.stepTimer = nil
    end
    state.stepQueue = 0
end

local function cancelDetection()
    if state.detectionTimer then
        state.detectionTimer:stop()
        state.detectionTimer = nil
    end
end

local function cancelSubmenuDetection()
    state.submenuGeneration = state.submenuGeneration + 1
    if state.submenuTimer then
        state.submenuTimer:stop()
        state.submenuTimer = nil
    end
end

local function resetGestureState()
    gestureState.armed = false
    gestureState.startedAt = 0
    gestureState.starts = {}
    gestureState.movedTooFar = false
end

local function deactivate(keepMenuIntent)
    state.generation = state.generation + 1
    cancelDetection()
    cancelSubmenuDetection()
    stopStepTimer()
    cancelPointerAnimation()
    resetGestureState()

    state.pending = false
    state.active = false
    state.rightHeld = false
    state.kind = nil
    state.source = nil
    state.menu = nil
    state.items = {}
    state.index = nil
    state.hasSnapped = false
    state.clickPoint = nil
    state.scrollAccumulator = 0
    state.smoothedVelocity = 0
    state.lastScrollTimestamp = nil
    state.menuStack = {}
    state.edgeArmedDirection = nil
    state.edgeArmedMenu = nil
    state.edgeArmedGestureSerial = nil
    state.scrollGestureSerial = 0
    state.lastPhysicalScrollAt = nil
    state.twoFingerMenuClick = nil

    if not keepMenuIntent then
        state.lastMenuBarIntent = nil
    end
end

------------------------------------------------------------
-- EDGE ESCAPE HELPERS
------------------------------------------------------------

local function clearEdgeEscape()
    state.edgeArmedDirection = nil
    state.edgeArmedMenu = nil
    state.edgeArmedGestureSerial = nil
end

local function atDirectionalEdge(direction)
    if not state.active or not state.index or #state.items == 0 then
        return false
    end

    if direction < 0 then return state.index <= 1 end
    return state.index >= #state.items
end

local function armEdgeEscape(direction)
    if not CONFIG.edgeEscapeToRoot or #state.menuStack == 0 then return end

    state.edgeArmedDirection = direction
    state.edgeArmedMenu = state.menu
    state.edgeArmedGestureSerial = state.scrollGestureSerial
end

------------------------------------------------------------
-- MAGNET MOVEMENT
------------------------------------------------------------

local function snapToCurrent(shouldFeedback)
    if not state.active or not state.index then return false end

    local item = state.items[state.index]
    if not item then return false end

    local dragMode = state.kind == "context"
        and CONFIG.holdSecondaryClick
        and state.rightHeld

    movePointerToItem(item, dragMode)
    state.hasSnapped = true

    if shouldFeedback then playFeedback() end
    return true
end

local function moveOneItem(direction)
    if not state.active or #state.items == 0 then return false end

    local newIndex = math.floor(clamp((state.index or 1) + direction, 1, #state.items))
    if newIndex == state.index then
        if #state.menuStack > 0 and atDirectionalEdge(direction) then
            armEdgeEscape(direction)
        end
        return false
    end

    state.index = newIndex
    snapToCurrent(true)

    if #state.menuStack > 0 and atDirectionalEdge(direction) then
        armEdgeEscape(direction)
    else
        clearEdgeEscape()
    end

    return true
end

local function processQueuedStep()
    if not state.active or state.stepQueue == 0 then
        stopStepTimer()
        return
    end

    local direction = state.stepQueue > 0 and 1 or -1

    if moveOneItem(direction) then
        state.stepQueue = state.stepQueue - direction
    else
        state.stepQueue = 0
    end

    if state.stepQueue == 0 then stopStepTimer() end
end

local function ensureStepTimer()
    if state.stepTimer then return end

    state.stepTimer = timer.doEvery(
        clamp(CONFIG.stepIntervalMs, 15, 140) / 1000,
        processQueuedStep
    )
end

local function enqueueSteps(direction, count)
    if not state.active then return end

    if not state.hasSnapped then
        snapToCurrent(true)
        count = count - 1
    end

    if count <= 0 then return end

    state.stepQueue = state.stepQueue + direction * count
    ensureStepTimer()
end

------------------------------------------------------------
-- MENU ACTIVATION / SUBMENU STACK
------------------------------------------------------------

local function activateMenu(menu, clickPoint, kind, source)
    local items = buildMenuItems(menu)
    if #items == 0 then return false end

    local current = hs.mouse.absolutePosition()
    local index = itemIndexAtPoint(items, current)
        or nearestItemIndex(items, current)
        or nearestItemIndex(items, clickPoint)
        or 1

    state.pending = false
    state.active = true
    state.kind = kind
    state.source = source
    state.menu = menu
    state.items = items
    state.index = index
    state.clickPoint = clickPoint
    state.scrollAccumulator = 0
    state.smoothedVelocity = 0
    state.lastScrollTimestamp = nil
    state.hasSnapped = itemIndexAtPoint(items, current) ~= nil
    state.menuStack = {}
    clearEdgeEscape()
    state.scrollGestureSerial = 0
    state.lastPhysicalScrollAt = nil

    debugAX("activated", kind, #items, "items")
    return true
end

local function currentSnapshot()
    return {
        menu = state.menu,
        items = state.items,
        index = state.index,
        kind = state.kind,
        source = state.source,
        clickPoint = state.clickPoint,
    }
end

local function restoreSnapshot(snapshot, shouldMovePointer, pointerPoint)
    if not snapshot or not snapshot.menu or not isValid(snapshot.menu) then
        return false
    end

    local freshItems = buildMenuItems(snapshot.menu)
    if #freshItems == 0 then freshItems = snapshot.items or {} end
    if #freshItems == 0 then return false end

    state.menu = snapshot.menu
    state.items = freshItems
    state.index = (pointerPoint and itemIndexAtPoint(freshItems, pointerPoint))
        or snapshot.index
        or 1
    state.index = math.floor(clamp(state.index, 1, #freshItems))
    state.kind = snapshot.kind
    state.source = snapshot.source
    state.clickPoint = snapshot.clickPoint
    state.pending = false
    state.active = true
    state.hasSnapped = pointerPoint and itemIndexAtPoint(freshItems, pointerPoint) ~= nil or true
    state.scrollAccumulator = 0
    state.smoothedVelocity = 0
    state.lastScrollTimestamp = nil
    clearEdgeEscape()

    if shouldMovePointer ~= false then
        local item = state.items[state.index]
        if item then movePointerToItem(item, false) end
    end

    return true
end

local function activateSubmenu(menu, parentSnapshot, anchorItem)
    local items = buildMenuItems(menu)
    if #items == 0 then return false end

    table.insert(state.menuStack, parentSnapshot)

    local anchorPoint = anchorItem and {
        x = anchorItem.frame.x + anchorItem.frame.w,
        y = anchorItem.frame.y + anchorItem.frame.h * 0.5,
    } or hs.mouse.absolutePosition()

    local index = nearestItemIndex(items, anchorPoint) or 1

    state.menu = menu
    state.items = items
    state.index = index
    state.hasSnapped = true
    state.scrollAccumulator = 0
    state.smoothedVelocity = 0
    state.lastScrollTimestamp = nil
    clearEdgeEscape()

    movePointerToItem(items[index], false)
    playFeedback()
    debugAX("entered submenu", #items, "items")
    return true
end

local function exitOneSubmenu()
    local parent = table.remove(state.menuStack)
    if not parent then return false end

    cancelSubmenuDetection()

    if not restoreSnapshot(parent) then
        deactivate(true)
        return false
    end

    playFeedback()
    debugAX("returned one submenu level")
    return true
end

local function returnToRootMenu()
    if #state.menuStack == 0 then
        return false
    end

    cancelSubmenuDetection()

    local root = state.menuStack[1]
    state.menuStack = {}

    if not restoreSnapshot(root) then
        deactivate(true)
        return false
    end

    playFeedback()
    debugAX("returned to root menu")
    return true
end

local function pointInsideFrame(point, f, pad)
    if not point or not f then return false end
    pad = pad or 0
    return point.x >= f.x - pad
        and point.x <= f.x + f.w + pad
        and point.y >= f.y - pad
        and point.y <= f.y + f.h + pad
end

-- Fixes the "ghost submenu" problem. If the user manually moves the pointer
-- from a child submenu back over one of its visible ancestors, that ancestor
-- immediately becomes the active magnetic menu again.
local function syncActiveMenuToPointer(point)
    if not state.active or not point then return false end

    -- v14: Prefer the visible child submenu's actual screen frame over the
    -- AX element ancestry. macOS can report a child item as a descendant of
    -- the parent AXMenu; treating that as a return-to-root causes click loops.
    local menuAtPointer = nil
    if pointInsideFrame(point, frameOf(state.menu), 2) then
        menuAtPointer = state.menu
    else
        for i = #state.menuStack, 1, -1 do
            local snapshot = state.menuStack[i]
            if snapshot and pointInsideFrame(point, frameOf(snapshot.menu), 1) then
                menuAtPointer = snapshot.menu
                break
            end
        end
    end
    if not menuAtPointer then
        menuAtPointer = findAncestorRole(elementAt(point), "AXMenu")
    end

    if not menuAtPointer then return false end

    if menuAtPointer == state.menu then
        local index = itemIndexAtPoint(state.items, point)
        if index then
            local changedItem = state.index ~= index
            state.index = index
            state.hasSnapped = true

            -- v13 FIX:
            -- Do NOT clear scrollAccumulator merely because the pointer is
            -- still sitting on the same magnetic row. processScroll() calls
            -- this function before every wheel event, so v12 accidentally
            -- erased small trackpad deltas before they could accumulate to
            -- scrollThreshold. Only a genuine manual move to another row
            -- should reset the accumulator.
            if changedItem then
                state.scrollAccumulator = 0
                state.smoothedVelocity = 0
                state.lastScrollTimestamp = nil
                clearEdgeEscape()
            end
        end
        return true
    end

    for i = #state.menuStack, 1, -1 do
        local snapshot = state.menuStack[i]
        if snapshot and snapshot.menu == menuAtPointer then
            local trimmed = {}
            for j = 1, i - 1 do
                trimmed[j] = state.menuStack[j]
            end

            if restoreSnapshot(snapshot, false, point) then
                state.menuStack = trimmed
                state.hasSnapped = true
                state.scrollAccumulator = 0
                clearEdgeEscape()
                debugAX("pointer returned to ancestor menu", i)
                return true
            end
        end
    end

    return false
end

local function escapeToRootAndAdvance(direction)
    if not CONFIG.edgeEscapeToRoot or #state.menuStack == 0 then return false end

    cancelSubmenuDetection()
    stopStepTimer()

    local root = state.menuStack[1]
    state.menuStack = {}

    if not restoreSnapshot(root, false, nil) then
        deactivate(true)
        return false
    end

    if CONFIG.edgeEscapeAdvanceRoot then
        state.index = math.floor(clamp((state.index or 1) + direction, 1, #state.items))
    end

    state.hasSnapped = true
    state.scrollAccumulator = 0
    clearEdgeEscape()
    snapToCurrent(true)
    debugAX("edge escape returned to root", direction)
    return true
end

local function performBackGesture()
    if not state.active then return false end

    if CONFIG.threeFingerBackMode == "parent" then
        return exitOneSubmenu()
    end

    return returnToRootMenu()
end

local function startSubmenuDetection(anchorItem)
    if not state.active or not anchorItem then return false end

    cancelSubmenuDetection()
    state.submenuGeneration = state.submenuGeneration + 1

    local generation = state.submenuGeneration
    local parentMenu = state.menu
    local parentSnapshot = currentSnapshot()

    -- Do not synthesize another click. Native macOS gets the user's click;
    -- we only wait for the submenu it opened and then attach to it.
    local remaining = 14

    local function attempt()
        if generation ~= state.submenuGeneration then return end
        if not state.active then return end
        if not parentMenu or not isValid(parentMenu) then
            deactivate(true)
            return
        end

        local submenu = visibleSubmenuNearItem(anchorItem, parentMenu)
        if submenu then
            state.submenuTimer = nil
            activateSubmenu(submenu, parentSnapshot, anchorItem)
            return
        end

        remaining = remaining - 1
        if remaining <= 0 then
            state.submenuTimer = nil
            debugAX("submenu follow timed out", anchorItem.title or "?")
            return
        end

        state.submenuTimer = timer.doAfter(0.030, attempt)
    end

    state.submenuTimer = timer.doAfter(0.020, attempt)
    return true
end

------------------------------------------------------------
-- TWO-FINGER / SECONDARY-CLICK SUBMENU ENTRY
------------------------------------------------------------

local function sameMenuItem(a, b)
    if not a or not b then return false end
    if a.element and b.element and a.element == b.element then return true end

    local af = a.frame
    local bf = b.frame
    if not af or not bf then return false end

    return a.title == b.title
        and math.abs(af.x - bf.x) < 2
        and math.abs(af.y - bf.y) < 2
        and math.abs(af.w - bf.w) < 2
        and math.abs(af.h - bf.h) < 2
end

local function itemHasKnownSubmenu(item)
    if not item or not item.element then return false end
    return submenuChildOfMenuItem(item.element) ~= nil
end

local function postSyntheticLeftClick(point)
    if not point then return end

    local down = event.newMouseEvent(types.leftMouseDown, point)
    down:setProperty(props.eventSourceUserData, MAGIC_EVENT_ID)
    down:post()

    timer.doAfter(0.012, function()
        local up = event.newMouseEvent(types.leftMouseUp, point)
        up:setProperty(props.eventSourceUserData, MAGIC_EVENT_ID)
        up:post()
    end)
end

local function beginTwoFingerMenuClick(point)
    if not CONFIG.twoFingerClickEntersSubmenu or not state.active then
        return false
    end

    local index = itemIndexAtPoint(state.items, point)
    local item = index and state.items[index] or nil
    if not item then return false end

    -- Prefer known AX submenu ownership. If AXChildren has not populated yet,
    -- accept a submenu that is already visible beside the row from hover.
    if CONFIG.twoFingerSubmenuOnly and not itemHasKnownSubmenu(item) then
        local visible = visibleSubmenuNearItem(item, state.menu)
        if not visible then
            return false
        end
    end

    state.index = index
    state.twoFingerMenuClick = {
        item = item,
        index = index,
        startPoint = { x = point.x, y = point.y },
        menu = state.menu,
    }

    return true
end

local function finishTwoFingerMenuClick(point)
    local click = state.twoFingerMenuClick
    state.twoFingerMenuClick = nil

    if not click or not state.active then return false end
    if click.menu ~= state.menu then return true end

    local dx = point.x - click.startPoint.x
    local dy = point.y - click.startPoint.y
    local distance = math.sqrt(dx * dx + dy * dy)

    if distance > (tonumber(CONFIG.twoFingerClickMaxMovementPx) or 12) then
        return true
    end

    local index = itemIndexAtPoint(state.items, point)
    local item = index and state.items[index] or nil
    if not item or not sameMenuItem(item, click.item) then
        return true
    end

    state.index = index

    -- Hover may already have opened the submenu. In that case simply attach.
    local visible = visibleSubmenuNearItem(item, state.menu)
    if visible then
        local parentSnapshot = currentSnapshot()
        activateSubmenu(visible, parentSnapshot, item)
        return true
    end

    -- Convert THIS secondary click into a left click only after the safety
    -- checks above. Our synthetic event ID prevents our event tap from seeing
    -- it as a fresh top-menu/menu-item click.
    postSyntheticLeftClick(point)
    timer.doAfter(0.018, function()
        if state.active then
            startSubmenuDetection(item)
        end
    end)

    return true
end

------------------------------------------------------------
-- TOP-MENU DETECTION + LAZY RECOVERY
------------------------------------------------------------

local function attemptDetection(clickPoint, remaining, generation, kind, source)
    if generation ~= state.generation then return end
    if not CONFIG.enabled then
        state.pending = false
        return
    end

    if kind == "context"
        and CONFIG.holdSecondaryClick
        and not state.rightHeld then
        state.pending = false
        return
    end

    local menu = nil
    local resolvedSource = source

    if kind == "menubar" then
        local allowFullScan = remaining <= 8
        menu, resolvedSource = findMenuBarMenu(source, clickPoint, allowFullScan)
    else
        menu = findContextMenu(clickPoint)
    end

    if menu and activateMenu(menu, clickPoint, kind, resolvedSource) then
        return
    end

    if remaining <= 0 then
        state.pending = false
        debugAX("detection timed out", kind)
        return
    end

    state.detectionTimer = timer.doAfter(CONFIG.detectionRetryDelay, function()
        attemptDetection(
            clickPoint,
            remaining - 1,
            generation,
            kind,
            resolvedSource
        )
    end)
end

local function startDetection(kind, clickPoint, source)
    cancelDetection()
    cancelSubmenuDetection()
    stopStepTimer()
    cancelPointerAnimation()

    state.generation = state.generation + 1
    local generation = state.generation

    state.pending = true
    state.active = false
    state.kind = kind
    state.source = source
    state.menu = nil
    state.items = {}
    state.index = nil
    state.hasSnapped = false
    state.clickPoint = clickPoint
    state.scrollAccumulator = 0
    state.smoothedVelocity = 0
    state.lastScrollTimestamp = nil
    state.menuStack = {}
    clearEdgeEscape()
    state.scrollGestureSerial = 0
    state.lastPhysicalScrollAt = nil

    if kind == "menubar" then
        state.lastMenuBarIntent = {
            point = clickPoint,
            source = source,
            time = nowSeconds(),
        }
    end

    state.detectionTimer = timer.doAfter(CONFIG.detectionDelay, function()
        attemptDetection(
            clickPoint,
            CONFIG.detectionRetries,
            generation,
            kind,
            source
        )
    end)
end

local function recoverOpenMenuForScroll()
    if not CONFIG.enabled or not CONFIG.menuBarMenus then return false end

    local intent = state.lastMenuBarIntent
    if not intent then return false end

    if nowSeconds() - intent.time > CONFIG.menuIntentLifetime then
        state.lastMenuBarIntent = nil
        return false
    end

    local pointer = hs.mouse.absolutePosition()

    -- Cheapest recovery first: if the pointer is already inside AXMenu.
    local direct = findAncestorRole(elementAt(pointer), "AXMenu")
    if direct and #buildMenuItems(direct) > 0 then
        debugAX("lazy recovery from pointer")
        return activateMenu(direct, intent.point, "menubar", intent.source)
    end

    -- Then retry the clicked MenuBarItem with a full fallback scan.
    local menu, source = findMenuBarMenu(intent.source, intent.point, true)
    if menu then
        debugAX("lazy recovery from first scroll")
        return activateMenu(menu, intent.point, "menubar", source)
    end

    return false
end

------------------------------------------------------------
-- SCROLL ENGINE
------------------------------------------------------------

local function velocityUnit()
    local sensitivity = clamp(CONFIG.velocitySensitivity, 0, 100) / 100
    return 2700 - sensitivity * 2200
end

local function calculateSteps(delta, accumulatedDistance, dt)
    local distanceSteps = math.max(
        1,
        math.floor(math.abs(accumulatedDistance) / math.max(1, CONFIG.scrollThreshold))
    )

    if not CONFIG.velocityScrolling then
        return math.min(distanceSteps, CONFIG.maxJump)
    end

    local instantaneousVelocity = math.abs(delta) / math.max(dt, 0.004)

    if state.smoothedVelocity == 0 then
        state.smoothedVelocity = instantaneousVelocity
    else
        state.smoothedVelocity = state.smoothedVelocity * 0.65
            + instantaneousVelocity * 0.35
    end

    local velocitySteps = math.max(
        1,
        math.floor(state.smoothedVelocity / velocityUnit())
    )

    return math.min(
        math.max(1, CONFIG.maxJump),
        math.max(distanceSteps, velocitySteps)
    )
end

local function processScroll(e)
    if not state.active then return false end

    if state.kind == "context"
        and CONFIG.holdSecondaryClick
        and not state.rightHeld then
        return false
    end

    -- Only submenus need pre-scroll parent/child reconciliation.
    -- At the root menu, normal mouseMoved events already keep the selected
    -- row synchronized. Avoiding an AX hit-test on every root scroll also
    -- keeps the basic magnetic path deterministic and lightweight.
    if #state.menuStack > 0 then
        syncActiveMenuToPointer(hs.mouse.absolutePosition())
    end

    -- Momentum is swallowed to stop overshoot after fingers are lifted.
    local momentum = e:getProperty(props.scrollWheelEventMomentumPhase) or 0
    if momentum ~= 0 then return true end

    local physicalNow = nowSeconds()
    local gestureGap = tonumber(CONFIG.edgeEscapeGestureGap) or 0.085

    if not state.lastPhysicalScrollAt
        or physicalNow - state.lastPhysicalScrollAt >= gestureGap then
        state.scrollGestureSerial = (state.scrollGestureSerial or 0) + 1
        state.smoothedVelocity = 0
    end
    state.lastPhysicalScrollAt = physicalNow

    local vertical = e:getProperty(props.scrollWheelEventPointDeltaAxis1) or 0
    if vertical == 0 then
        vertical = e:getProperty(props.scrollWheelEventFixedPtDeltaAxis1) or 0
    end

    -- Read and deliberately discard horizontal movement. The open macOS menu
    -- never receives the diagonal component, so File/Edit/View cannot switch
    -- merely because the user's two-finger vertical gesture drifted sideways.
    if CONFIG.ignoreHorizontalScroll then
        local _horizontal = e:getProperty(props.scrollWheelEventPointDeltaAxis2) or 0
        if _horizontal == 0 then
            _horizontal = e:getProperty(props.scrollWheelEventFixedPtDeltaAxis2) or 0
        end
    end

    if vertical == 0 then return true end
    if CONFIG.invertScroll then vertical = -vertical end

    local timestamp = e:timestamp()
    local dt = 0.016

    if state.lastScrollTimestamp
        and timestamp
        and timestamp > state.lastScrollTimestamp then
        dt = clamp(
            (timestamp - state.lastScrollTimestamp) / 1000000000,
            0.004,
            0.050
        )
    end

    state.lastScrollTimestamp = timestamp
    state.scrollAccumulator = state.scrollAccumulator + vertical

    if math.abs(state.scrollAccumulator) < CONFIG.scrollThreshold then
        return true
    end

    local direction = state.scrollAccumulator >= 0 and -1 or 1
    local steps = calculateSteps(vertical, state.scrollAccumulator, dt)
    state.scrollAccumulator = 0

    -- Submenu edge escape:
    -- 1) reaching the edge arms it;
    -- 2) continuing the SAME physical gesture only stops there;
    -- 3) lift fingers and scroll again in the same direction -> root menu.
    if CONFIG.edgeEscapeToRoot
        and #state.menuStack > 0
        and atDirectionalEdge(direction) then

        if state.edgeArmedMenu ~= state.menu
            or state.edgeArmedDirection ~= direction then
            armEdgeEscape(direction)
            return true
        end

        if state.edgeArmedGestureSerial ~= nil
            and state.scrollGestureSerial > state.edgeArmedGestureSerial then
            escapeToRootAndAdvance(direction)
            return true
        end

        return true
    end

    -- Moving away from an armed edge cancels the escape intent.
    if state.edgeArmedDirection and state.edgeArmedDirection ~= direction then
        clearEdgeEscape()
    end

    enqueueSteps(direction, steps)
    return true
end

local function syncIndexFromPointer(point)
    if not state.active then return end

    if syncActiveMenuToPointer(point) then
        return
    end

    local index = itemIndexAtPoint(state.items, point)
    if index then
        local changedItem = state.index ~= index
        state.index = index
        state.hasSnapped = true

        -- Same rule as syncActiveMenuToPointer(): preserve accumulated
        -- wheel distance while the pointer remains on the current row.
        if changedItem then
            state.scrollAccumulator = 0
            state.smoothedVelocity = 0
            state.lastScrollTimestamp = nil
            clearEdgeEscape()
        end
    end
end

------------------------------------------------------------
-- THREE-FINGER BACK GESTURE
------------------------------------------------------------

local function indirectTouches(e)
    local touches = safeCall(function() return e:getTouches() end, {})
    if type(touches) ~= "table" then return {}, {} end

    local all = {}
    local touching = {}

    for _, t in ipairs(touches) do
        if t.type == "indirect" then
            table.insert(all, t)
            if t.touching then table.insert(touching, t) end
        end
    end

    return all, touching
end

local function armThreeFingerTap(touching)
    gestureState.armed = true
    gestureState.startedAt = nowSeconds()
    gestureState.starts = {}
    gestureState.movedTooFar = false

    for _, t in ipairs(touching) do
        if t.identity and t.normalizedPosition then
            gestureState.starts[t.identity] = {
                x = t.normalizedPosition.x,
                y = t.normalizedPosition.y,
            }
        end
    end
end

local function updateThreeFingerMovement(allTouches)
    if not gestureState.armed then return end

    for _, t in ipairs(allTouches) do
        local start = t.identity and gestureState.starts[t.identity]
        local p = t.normalizedPosition

        if start and p then
            local dx = p.x - start.x
            local dy = p.y - start.y
            local distance = math.sqrt(dx * dx + dy * dy)

            if distance > CONFIG.threeFingerMaxMovement then
                gestureState.movedTooFar = true
                return
            end
        end
    end
end

local function handleThreeFingerGesture(e)
    if not CONFIG.threeFingerBack or not state.active then
        resetGestureState()
        return false
    end

    local allTouches, touching = indirectTouches(e)
    local count = #touching

    if not gestureState.armed then
        if count == 3 then
            armThreeFingerTap(touching)
            return CONFIG.consumeThreeFingerTap
        end
        return false
    end

    updateThreeFingerMovement(allTouches)

    if count > 3 then
        resetGestureState()
        return false
    end

    local age = nowSeconds() - gestureState.startedAt

    if gestureState.movedTooFar or age > CONFIG.threeFingerMaxDuration then
        resetGestureState()
        return false
    end

    -- All fingers released after a short, stationary 3-finger contact.
    if count == 0 then
        local shouldConsume = CONFIG.consumeThreeFingerTap
        performBackGesture()
        resetGestureState()
        return shouldConsume
    end

    return CONFIG.consumeThreeFingerTap
end

------------------------------------------------------------
-- OWN MENU-BAR ITEM EXCLUSION
------------------------------------------------------------

local function isOwnStatusMenuPoint(point)
    if not point or not menuBar then return false end

    local ok, f = pcall(function() return menuBar:frame() end)
    if not ok or not f then return false end

    return point.x >= f.x - 4
        and point.x <= f.x + f.w + 4
        and point.y >= f.y - 4
        and point.y <= f.y + f.h + 4
end

------------------------------------------------------------
-- EVENT TAP
------------------------------------------------------------

local function isSynthetic(e)
    return e:getProperty(props.eventSourceUserData) == MAGIC_EVENT_ID
end

local function handleEvent(e)
    if isSynthetic(e) then return false end

    local eventType = e:getType()

    --------------------------------------------------------
    -- RAW TRACKPAD GESTURES
    --------------------------------------------------------

    if eventType == types.gesture then
        if CONFIG.threeFingerBack then
            return handleThreeFingerGesture(e)
        end
        return false
    end

    --------------------------------------------------------
    -- MIDDLE CLICK = OPTIONAL 3-FINGER-BACK FALLBACK
    --------------------------------------------------------

    if eventType == types.otherMouseDown
        and CONFIG.middleClickAlsoBack
        and state.active then
        local button = e:getProperty(props.mouseEventButtonNumber) or 0
        if button == 2 then
            performBackGesture()
            return true
        end
    end

    --------------------------------------------------------
    -- TWO-FINGER CLICK INSIDE AN EXISTING MENU
    --
    -- macOS exposes the Trackpad "Click with Two Fingers" secondary
    -- click as rightMouseDown/rightMouseUp. This must run BEFORE the
    -- normal context-menu path or the current menu gets deactivated.
    --------------------------------------------------------

    if eventType == types.rightMouseDown and state.active then
        if beginTwoFingerMenuClick(e:location()) then
            return true
        end
    end

    if eventType == types.rightMouseUp and state.twoFingerMenuClick then
        finishTwoFingerMenuClick(e:location())
        return true
    end

    --------------------------------------------------------
    -- RIGHT-CLICK CONTEXT MENUS
    --------------------------------------------------------

    if eventType == types.rightMouseDown then
        deactivate(false)
        state.rightHeld = true

        local point = e:location()
        state.clickPoint = point

        if CONFIG.enabled
            and CONFIG.rightClickMenus
            and CONFIG.holdSecondaryClick then
            startDetection("context", point, nil)
        end

        return false
    end

    if eventType == types.rightMouseUp then
        local point = e:location()

        if CONFIG.holdSecondaryClick then
            state.rightHeld = false
            deactivate(false)
            return false
        end

        state.rightHeld = false

        if CONFIG.enabled and CONFIG.rightClickMenus then
            startDetection("context", point, nil)
        end

        return false
    end

    --------------------------------------------------------
    -- FILE / EDIT / VIEW / DEVELOP / ETC.
    --------------------------------------------------------

    if eventType == types.leftMouseDown
        and CONFIG.enabled
        and CONFIG.menuBarMenus then
        local point = e:location()

        -- Never magnetise Menu Magnet's own status item.
        if isOwnStatusMenuPoint(point) then
            deactivate(false)
            return false
        end

        -- A click inside an open submenu must NEVER be reclassified as a
        -- fresh File/Edit menu-bar click (even if AX parent includes a
        -- MenuBarItem). This was another possible source of the jump-to-root.
        local insideOpenMenu = state.active and
            pointInsideFrame(point, frameOf(state.menu), 2)
        if not insideOpenMenu and state.active then
            for _, snapshot in ipairs(state.menuStack) do
                if pointInsideFrame(point, frameOf(snapshot.menu), 2) then
                    insideOpenMenu = true
                    break
                end
            end
        end
        local menuBarItem = (not insideOpenMenu) and menuBarItemAtPoint(point) or nil

        if menuBarItem then
            -- A new TOP MENU is entered only by an actual click.
            -- Mouse movement / diagonal scrolling can no longer switch it.
            deactivate(false)
            startDetection("menubar", point, menuBarItem)
            return false
        end
    end

    --------------------------------------------------------
    -- SCROLL: ACTIVE MENU OR LAZY TOP-MENU RECOVERY
    --------------------------------------------------------

    if eventType == types.scrollWheel then
        if state.active then
            return processScroll(e)
        end

        -- If normal post-click AX detection missed the menu, the first
        -- scroll event gets one immediate recovery pass. This is much more
        -- reliable than depending only on timing after the click.
        if recoverOpenMenuForScroll() then
            return processScroll(e)
        end

        -- If detection is still pending, swallow the scroll so the page
        -- behind the open menu does not move.
        if state.pending then return true end

        return false
    end

    --------------------------------------------------------
    -- PENDING DETECTION
    --------------------------------------------------------

    if state.pending then
        return false
    end

    if not state.active then return false end

    --------------------------------------------------------
    -- NORMAL POINTER MOVEMENT / ANCESTOR RECOVERY
    --------------------------------------------------------

    if eventType == types.mouseMoved
        or eventType == types.rightMouseDragged then
        -- Do this BEFORE validating the current child menu. macOS may destroy
        -- the child AXMenu as soon as the pointer moves back to its parent;
        -- the parent snapshot is still valid and should take control instead
        -- of deactivating the whole magnetic session.
        syncIndexFromPointer(e:location())

        if state.menu and isValid(state.menu) then
            return false
        end
    end

    --------------------------------------------------------
    -- MENU VALIDITY
    --------------------------------------------------------

    if not state.menu or not isValid(state.menu) then
        -- Last chance: recover whichever visible ancestor is under the pointer
        -- before throwing away the submenu stack.
        if #state.menuStack > 0
            and syncActiveMenuToPointer(hs.mouse.absolutePosition())
            and state.menu
            and isValid(state.menu) then
            return false
        end

        -- Preserve recent top-menu intent briefly so a later scroll can
        -- recover if macOS replaced the AXMenu object under us.
        deactivate(state.kind == "menubar")
        return false
    end

    --------------------------------------------------------
    -- CLICK DOWN INTO SUBMENU
    --------------------------------------------------------

    if eventType == types.leftMouseDown then
        local point = e:location()
        -- Remove any outstanding synthetic pointer movements BEFORE the native
        -- click, otherwise the click lands in the former parent row.
        stopStepTimer()
        cancelPointerAnimation()
        cancelSubmenuDetection()
        syncActiveMenuToPointer(point)
        local clickedIndex = itemIndexAtPoint(state.items, point)
        local clickedItem = clickedIndex and state.items[clickedIndex] or nil

        -- Leaf commands: release Menu Magnet immediately, let the actual macOS
        -- click complete normally. Only submenu owners need submenu recovery.
        if clickedItem and not itemHasKnownSubmenu(clickedItem) and
            not visibleSubmenuNearItem(clickedItem, state.menu) then
            deactivate(false)
            return false
        end

        if CONFIG.clickEntersSubmenu and clickedItem then
            state.index = clickedIndex

            -- Let macOS process the real click. Then watch briefly for a
            -- submenu beside the clicked row. If no submenu appears, this
            -- was a normal command and macOS is free to close the menu.
            timer.doAfter(0.015, function()
                if state.active then
                    startSubmenuDetection(clickedItem)
                end
            end)

            return false
        end

        deactivate(false)
        return false
    end

    --------------------------------------------------------
    -- KEYBOARD TAKES CONTROL BACK
    --------------------------------------------------------

    if eventType == types.keyDown then
        deactivate(false)
        return false
    end

    return false
end

------------------------------------------------------------
-- LIGHTWEIGHT NATIVE MENU-BAR MENU
------------------------------------------------------------

local function buildMenuBarMenu()
    return {
        {
            title = "Enabled",
            checked = CONFIG.enabled,
            fn = function() CONFIG.enabled = not CONFIG.enabled end,
        },
        { title = "-" },
        {
            title = "Haptic feedback",
            checked = CONFIG.hapticEnabled,
            fn = function() CONFIG.hapticEnabled = not CONFIG.hapticEnabled end,
        },
        {
            title = "Subtle sound fallback",
            checked = CONFIG.soundFallbackEnabled,
            fn = function()
                CONFIG.soundFallbackEnabled = not CONFIG.soundFallbackEnabled
            end,
        },
        {
            title = "Right-click menus",
            checked = CONFIG.rightClickMenus,
            fn = function() CONFIG.rightClickMenus = not CONFIG.rightClickMenus end,
        },
        {
            title = "Top menu-bar menus",
            checked = CONFIG.menuBarMenus,
            fn = function() CONFIG.menuBarMenus = not CONFIG.menuBarMenus end,
        },
        {
            title = "1-finger click enters submenu",
            checked = CONFIG.clickEntersSubmenu,
            fn = function()
                CONFIG.clickEntersSubmenu = not CONFIG.clickEntersSubmenu
            end,
        },
        {
            title = "2-finger click enters submenu",
            checked = CONFIG.twoFingerClickEntersSubmenu,
            fn = function()
                CONFIG.twoFingerClickEntersSubmenu = not CONFIG.twoFingerClickEntersSubmenu
            end,
        },
        {
            title = "Edge scroll escapes submenu",
            checked = CONFIG.edgeEscapeToRoot,
            fn = function() CONFIG.edgeEscapeToRoot = not CONFIG.edgeEscapeToRoot end,
        },
        { title = "-" },
        {
            title = "Test feedback",
            fn = playFeedback,
        },
        {
            title = "Open Lua Config    ⌃⌥⌘P",
            fn = openConfigFile,
        },
        {
            title = "Reload Hammerspoon    ⌃⌥⌘R",
            fn = function() hs.reload() end,
        },
    }
end

------------------------------------------------------------
-- RELOAD-SAFE CLEANUP
------------------------------------------------------------

-- Legacy global tap from older single-file versions.
if _G.MenuMagnetTap then
    pcall(function() _G.MenuMagnetTap:stop() end)
    _G.MenuMagnetTap = nil
end

for _, key in ipairs({
    "MenuMagnetV8Tap",
    "MenuMagnetV9Tap",
    "MenuMagnetV10Tap",
    "MenuMagnetV11Tap",
    "MenuMagnetV12Tap",
}) do
    if _G[key] then
        pcall(function() _G[key]:stop() end)
        _G[key] = nil
    end
end

for _, key in ipairs({
    "MenuMagnetV8MenuBar",
    "MenuMagnetV9MenuBar",
    "MenuMagnetV10MenuBar",
    "MenuMagnetV11MenuBar",
    "MenuMagnetV12MenuBar",
}) do
    if _G[key] then
        pcall(function() _G[key]:delete() end)
        _G[key] = nil
    end
end

for _, key in ipairs({
    "MenuMagnetV8SettingsHotkey",
    "MenuMagnetV8ToggleHotkey",
    "MenuMagnetV9SettingsHotkey",
    "MenuMagnetV9ToggleHotkey",
    "MenuMagnetV10OpenHotkey",
    "MenuMagnetV10ToggleHotkey",
    "MenuMagnetV10ReloadHotkey",
    "MenuMagnetV11OpenHotkey",
    "MenuMagnetV11ToggleHotkey",
    "MenuMagnetV11ReloadHotkey",
    "MenuMagnetV12OpenHotkey",
    "MenuMagnetV12ToggleHotkey",
    "MenuMagnetV12ReloadHotkey",
}) do
    if _G[key] then
        pcall(function() _G[key]:delete() end)
        _G[key] = nil
    end
end

------------------------------------------------------------
-- START
------------------------------------------------------------

local watchedEvents = {
    types.rightMouseDown,
    types.rightMouseUp,
    types.rightMouseDragged,
    types.leftMouseDown,
    types.otherMouseDown,
    types.mouseMoved,
    types.scrollWheel,
    types.keyDown,
}

-- Gesture events are available on current Hammerspoon builds. Keep the
-- guard so an older build can still load v12 without failing entirely.
if CONFIG.threeFingerBack and types.gesture then
    table.insert(watchedEvents, types.gesture)
end

MenuMagnetTap = eventtap.new(watchedEvents, handleEvent)
MenuMagnetTap:start()
_G.MenuMagnetV12Tap = MenuMagnetTap

if CONFIG.showMenuBarItem then
    menuBar = hs.menubar.new(true, "MenuMagnetV12")
    if menuBar then
        menuBar:setTitle(CONFIG.menuBarTitle or "⇵")
        menuBar:setTooltip("Menu Magnet v13")
        menuBar:setMenu(buildMenuBarMenu)
        _G.MenuMagnetV12MenuBar = menuBar
    end
end

_G.MenuMagnetV12OpenHotkey = hs.hotkey.bind(
    CONFIG.openConfigHotkey.mods,
    CONFIG.openConfigHotkey.key,
    openConfigFile
)

_G.MenuMagnetV12ToggleHotkey = hs.hotkey.bind(
    CONFIG.toggleHotkey.mods,
    CONFIG.toggleHotkey.key,
    function()
        CONFIG.enabled = not CONFIG.enabled
        deactivate(false)
        if CONFIG.showAlerts then
            hs.alert.show(CONFIG.enabled and "Menu Magnet ON" or "Menu Magnet OFF")
        end
    end
)

_G.MenuMagnetV12ReloadHotkey = hs.hotkey.bind(
    CONFIG.reloadHotkey.mods,
    CONFIG.reloadHotkey.key,
    function() hs.reload() end
)

------------------------------------------------------------
-- LOADED
------------------------------------------------------------

print("[MenuMagnet] v13 loaded")
print("[MenuMagnet] config file:", SCRIPT_PATH)
print("[MenuMagnet] right-click menus:", CONFIG.rightClickMenus)
print("[MenuMagnet] top menu-bar menus:", CONFIG.menuBarMenus)
print("[MenuMagnet] 1-finger click enters submenu:", CONFIG.clickEntersSubmenu)
print("[MenuMagnet] 2-finger click enters submenu:", CONFIG.twoFingerClickEntersSubmenu)
print("[MenuMagnet] edge escape to root:", CONFIG.edgeEscapeToRoot)
print("[MenuMagnet] 3-finger back (experimental):", CONFIG.threeFingerBack)
print("[MenuMagnet] horizontal scroll ignored:", CONFIG.ignoreHorizontalScroll)

if MACTIC_PATH then
    print("[MenuMagnet] haptics ready:", MACTIC_PATH)
else
    print("[MenuMagnet] mactic unavailable; sound fallback can be used")
end

if SUBTLE_SOUND then
    print("[MenuMagnet] subtle sound ready:", SUBTLE_SOUND_NAME)
end
