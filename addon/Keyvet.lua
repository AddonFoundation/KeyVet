local ADDON_NAME = "Keyvet"

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, loadedAddon)
    if event == "ADDON_LOADED" then
        if loadedAddon ~= ADDON_NAME then return end

        if not KeyvetDB then
            print("|cffff0000Keyvet:|r data file failed to load — KeyvetDB is missing.")
            return
        end

        local charCount = 0
        for _ in pairs(KeyvetDB) do charCount = charCount + 1 end

        local realmCount = 0
        if KeyvetRealmMap then
            for _ in pairs(KeyvetRealmMap) do realmCount = realmCount + 1 end
        end

        print(string.format("|cff00ff00Keyvet loaded:|r %d characters, %d realms mapped.", charCount, realmCount))
    elseif event == "PLAYER_LOGIN" then
        Keyvet_HookApplicantViewer()
    end
end)

-- Accepts either ("Name-Realm") combined, or ("Name", "RealmDisplayName") separately.
function Keyvet_LookupCharacter(fullNameOrName, realmDisplayName, region)
    region = region or "us"

    local charName, embeddedRealm
    if realmDisplayName == nil then
        charName, embeddedRealm = strsplit("-", fullNameOrName, 2)
    else
        charName = fullNameOrName
        embeddedRealm = realmDisplayName
    end

    if not embeddedRealm or embeddedRealm == "" then
        embeddedRealm = GetNormalizedRealmName()
    end

    local realmSlug = KeyvetRealmMap and KeyvetRealmMap[embeddedRealm]
    if not realmSlug then
        return nil  -- realm not in our known map, can't safely guess
    end

    local key = string.format("%s-%s-%s", region, charName, realmSlug)
    return KeyvetDB[key]
end

-- Returns a color code + short label for a given character record (or nil if not found)
local function Keyvet_Evaluate(entry)
    if not entry then
        return "|cff888888", "No data"
    end
    if entry.depletedCount == 0 and entry.runCount >= 3 then
        return "|cff00ff00", "Reliable"
    end
    if entry.depletedCount > 0 and entry.timedCount > entry.depletedCount then
        return "|cffffff00", "Mixed"
    end
    if entry.depletedCount >= entry.timedCount then
        return "|cffff0000", "Frequent deplete"
    end
    return "|cff888888", "Unclear"
end

local function Keyvet_TagApplicantFrame(memberFrame, fullName)
    if not memberFrame or not memberFrame.Name then return end

    local entry = Keyvet_LookupCharacter(fullName)
    local color, label = Keyvet_Evaluate(entry)

    if not memberFrame.KeyvetTag then
        memberFrame.KeyvetTag = memberFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        memberFrame.KeyvetTag:SetPoint("RIGHT", memberFrame, "RIGHT", -4, 0)
    end
    memberFrame.KeyvetTag:SetText(color .. label .. "|r")
end

function Keyvet_HookApplicantViewer()
    if not LFGListApplicantMemberFrame_UpdateAppearance then
        print("|cffff0000Keyvet:|r LFGListApplicantMemberFrame_UpdateAppearance not found — group finder UI may have changed.")
        return
    end

    hooksecurefunc("LFGListApplicantMemberFrame_UpdateAppearance", function(memberFrame)
        local applicantID = memberFrame:GetParent() and memberFrame:GetParent().applicantID
        if not applicantID then return end

        local memberIdx = memberFrame.memberIdx
        if not memberIdx then return end

        local name = C_LFGList.GetApplicantMemberInfo(applicantID, memberIdx)
        if not name then return end

        Keyvet_TagApplicantFrame(memberFrame, name)
    end)

    print("|cff00ff00Keyvet:|r Hooked into group finder applicant list.")
end
