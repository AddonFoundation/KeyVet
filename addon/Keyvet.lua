local ADDON_NAME = "Keyvet"

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon ~= ADDON_NAME then return end

    if not KeyvetDB then
        print("|cffff0000Keyvet:|r data file failed to load — KeyvetDB is missing.")
        return
    end

    local count = 0
    for _ in pairs(KeyvetDB) do count = count + 1 end
    print(string.format("|cff00ff00Keyvet loaded:|r %d characters in database.", count))
end)

-- Exact-key lookup
function Keyvet_LookupCharacter(name, realm, region)
    region = region or "us"
    local key = string.format("%s-%s-%s", region, name, realm)
    return KeyvetDB[key]
end

-- Returns a color code + short label for a given character record (or nil if not found)
local function Keyvet_Evaluate(entry)
    if not entry then
        return "|cff888888", "No data"
    end
    if entry.depletedCount == 0 and entry.runCount >= 3 then
        return "|cff00ff00", "Reliable"  -- green
    end
    if entry.depletedCount > 0 and entry.timedCount > entry.depletedCount then
        return "|cffffff00", "Mixed"     -- yellow
    end
    if entry.depletedCount >= entry.timedCount then
        return "|cffff0000", "Frequent deplete"  -- red
    end
    return "|cff888888", "Unclear"
end

-- Attempts to resolve a character's realm from what the LFG API gives us.
-- Applicant member info doesn't always include realm directly for same-realm players,
-- so we fall back to the player's own realm when none is provided.
local function Keyvet_ResolveRealm(realm)
    if realm == nil or realm == "" then
        return GetNormalizedRealmName()
    end
    return realm
end

local function Keyvet_TagApplicantFrame(memberFrame, name, realm)
    if not memberFrame or not memberFrame.Name then return end

    realm = Keyvet_ResolveRealm(realm)
    local entry = Keyvet_LookupCharacter(name, realm:gsub("%s+", ""):lower(), "us")
    local color, label = Keyvet_Evaluate(entry)

    if not memberFrame.KeyvetTag then
        memberFrame.KeyvetTag = memberFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        memberFrame.KeyvetTag:SetPoint("RIGHT", memberFrame, "RIGHT", -4, 0)
    end
    memberFrame.KeyvetTag:SetText(color .. label .. "|r")
end

-- Hook into the applicant viewer — fires when Blizzard updates each applicant member row
local function Keyvet_HookApplicantViewer()
    if not LFGListApplicationViewer then
        print("|cffff0000Keyvet:|r LFGListApplicationViewer not found — group finder UI may have changed.")
        return
    end

    hooksecurefunc("LFGListApplicantMemberFrame_UpdateAppearance", function(memberFrame)
        local applicantID = memberFrame:GetParent() and memberFrame:GetParent().applicantID
        if not applicantID then return end

        local memberIdx = memberFrame.memberIdx
        if not memberIdx then return end

        local name, _, _, _, _, _, _, _, _, _, realm = C_LFGList.GetApplicantMemberInfo(applicantID, memberIdx)
        if not name then return end

        Keyvet_TagApplicantFrame(memberFrame, name, realm)
    end)

    print("|cff00ff00Keyvet:|r Hooked into group finder applicant list.")
end

frame:RegisterEvent("PLAYER_LOGIN")
frame:HookScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        Keyvet_HookApplicantViewer()
    end
end)
