print("Loaded Synex Proxy PRO")

-------------------------------------
-- Durum Degiskenleri
-------------------------------------
local modfly_on    = false
local ghost_on     = false
local autowear_on  = false
local afk_on       = false
local pullgas_on   = false
local banpocket_on = false
local blocksdb_on  = false
local checkgems_on = false
local fastwheel_on = false
local autocbgl_on  = false
local reme_on      = true
local fastdrop_on  = false
local fasttrash_on = false
local netid_on     = false
local moddetect_on = false
local md_unaccess  = true   -- mod gelince access birak
local md_exit      = true   -- mod gelince EXIT'e git
local md_banall    = false  -- mod gelince herkesi banla (RISKLI)
local md_warn      = true   -- mod gelince uyari ver
local md_collect   = false  -- mod gelince yerdeki itemleri topla
local wrench_on    = false
local autoacc_on   = false
local hidelevel_on = false
local punchtp_on   = false   -- Pathfind: kar topuyla bir yere vurunca oraya isinlan
local punchtp_item = 1368    -- kar topu item id (/pkttest'te value=1368 cikti)
local wrench_mode  = "pull"  -- pull / kick / ban / worldban
local nameset      = false
local orig_name    = ""

-- Gorsel kiyafet slotlari (sadece sende gorunur)
local cloth = { hat=0, shirt=0, pants=0, feet=0, face=0, hand=0, back=0, hair=0, neck=0, ances=0 }

-- AFK
local afk_timer = 0

-- Pozisyonlar
local pos = { {0,0}, {0,0}, {0,0}, {0,0} }

-- Gem takibi
local OIDList = {}
local Gems    = 0

-- CSN
local csn_earned = 0
local csn_tax    = 16
local csn_bet    = 500

-- WrenchMenu engellemek icin flag
local wrench_block_next = false
local dlgtest_on = false
local pkttest_on = false

-------------------------------------
-- Hos Geldin
-------------------------------------
local welcome = {
    title   = "`9Hos Geldiniz!",
    message = "`b`oSynex`w Proxy PRO'ya hos geldiniz!\n\n`oDevam etmek icin bir buton secin.",
    confirm = "Devam",
    ignore  = "Kapat",
    alias   = "proxy_welcome"
}

-------------------------------------
-- Yardimci Fonksiyonlar
-------------------------------------
local function log(msg)
    LogToConsole("`7[`9Synex`7]`o " .. tostring(msg))
end

local function inv(id)
    for _, item in pairs(GetInventory()) do
        if item.id == id then return item.amount end
    end
    return 0
end

local function overlay(str)
    SendVariant({ v1="OnTextOverlay", v2=str })
end

local function ont(str)
    SendVariant({ v1="OnTalkBubble", v2=GetLocal().netID, v3=str })
end

local function wear(id)
    SendPacketRaw(false, { type=10, value=id })
end

local function st(v) return v and "`2ACIK" or "`4KAPALI" end

-- Kulo birebir: dunyadan cik (quit_to_exit)
local function exit_world()
    log("`b[Mod Detect] Dunyadan cikiliyor...")
    SendPacket(3, "action|quit_to_exit")
end

-- Kulo birebir: tum lock'lardan access'i birak
local function unaccess()
    log("`b[Mod Detect] Access birakiliyor...")
    SendPacket(2, "action|input\n|text|/unaccess")
    CSleep(300)
    SendPacket(2, "action|dialog_return\ndialog_name|unaccess\nbuttonClicked|Yes")
end

-- Kulo birebir: dunyadaki herkesi banla
local function ban_everyone()
    local players = (GetPlayers and GetPlayers()) or {}
    for _, p in ipairs(players) do
        if p.netID ~= GetLocal().netID then
            SendPacket(2, "action|dialog_return\ndialog_name|popup\nnetID|"..p.netID.."|\nbuttonClicked|worldban")
            CSleep(30)
        end
    end
end

local function rdrop(id, amount)
    growtopia.dropItem(id)
    CSleep(100)
    growtopia.confirmDropItem(id, amount)
end

local function smartdrop(id, amount, name)
    local have = inv(id)
    if have < amount then
        overlay("`4Yeterli " .. name .. " yok! Mevcut: " .. have)
        return false
    end
    rdrop(id, amount)
    log("`2" .. amount .. " " .. name .. " dusuruldu.")
    return true
end

local function drop_dw(str)
    local n = tonumber(str)
    if not n then overlay("`4Gecersiz miktar.") return end
    local dl = math.floor(n / 100)
    local wl = n % 100
    log("`5" .. str .. " → DL: " .. dl .. "  WL: " .. wl)
    if dl > 0 then smartdrop(1796, dl, "Diamond Lock") CSleep(400) end
    if wl > 0 then smartdrop(242,  wl, "World Lock")   end
end

local function safepos(x, y)
    local ok, tiles = pcall(GetTiles, x, y)
    if not ok then return false end
    return tiles and tiles.collidable
end

-- Pozisyona isinlan.
-- ESKI: sadece OnSetPos varianti → bu yalnizca EKRANI isinliyordu, sunucu eski
-- konumunda saniyordu, bu yuzden /w1 vb. drop ayaginin dibine dusuyordu.
-- YENI: /pkttest ile state paketinin (type=0) x/y tasidigini gorduk → sunucuya da
-- type=0 paketi gonderip gercekten oraya tasiyoruz (px/py = pixel).
local function tptopos(px, py)
    SendVariant({ v1="OnSetPos", v2={ px, py } }, GetLocal().netID)        -- gorsel (ekran)
    SendPacketRaw(false, { type=0, netid=GetLocal().netID, value=0, x=px, y=py })  -- sunucu
end

-- Auto Collect (Kulo autoc birebir): 10 tile menzilindeki tum itemleri topla
-- Kulo: packet{type=11, pos_x=item.x, pos_y=item.y, netid=-1, object_id=item.uid}
-- Growlauncher type 11'de object_id = "value" alaninda (CheckGems'te dogrulandi)
local function auto_collect(range)
    range = range or 320  -- varsayilan 10 tile (320 px); take icin dar verilir
    local lx = GetLocal().posX
    local ly = GetLocal().posY
    local count = 0
    local ok, list = pcall(GetObjectList)
    if not ok or not list then
        log("`4[Collect] GetObjectList calismadi.")
        return 0
    end
    for _, obj in pairs(list) do
        if obj.posX and obj.posY then
            local dx = math.abs(obj.posX - lx)
            local dy = math.abs(obj.posY - ly)
            if dx <= range and dy <= range then
                -- object id: Growlauncher'da obj.id (CheckGems'te obj.id kullanildi)
                local oid = obj.id or obj.uid or obj.oid
                SendPacketRaw(false, {
                    type = 11,
                    netid = -1,
                    value = oid,
                    x = obj.posX,
                    y = obj.posY
                })
                count = count + 1
            end
        end
    end
    if count > 0 then log("`2[Collect] "..count.." item toplandi.") else log("`7[Collect] Menzilde item yok.") end
    return count
end

-- Mod tepkisi: secilen ayarlara gore (hem otomatik tespit hem /mdtest kullanir)
local function trigger_mod_response(reason)
    if md_warn then
        log("`4[MOD TESPIT] "..(reason or "Mod var").."!")
        overlay("`4⚠ MOD TESPIT! ("..(reason or "mod")..")")
    end
    -- 1) Un-access (seciliyse)
    if md_unaccess then
        SendPacket(2, "action|input\n|text|/unaccess")
        CSleep(300)
        SendPacket(2, "action|dialog_return\ndialog_name|unaccess\nbuttonClicked|Yes")
        CSleep(200)
        log("`2[MOD] Access birakildi.")
    end
    -- 2) Once yerdeki itemleri topla (seciliyse - banlamadan once BGL/item topla)
    if md_collect then
        auto_collect()
        CSleep(150)
    end
    -- 3) Ban everyone (seciliyse - RISKLI)
    if md_banall then
        local players = (GetPlayers and GetPlayers()) or {}
        local n = 0
        for _, p in ipairs(players) do
            if p.netID ~= GetLocal().netID then
                SendPacket(2, "action|dialog_return\ndialog_name|popup\nnetID|"..p.netID.."|\nbuttonClicked|worldban")
                CSleep(30) n = n + 1
            end
        end
        log("`2[MOD] "..n.." kisi banlandi.")
    end
    -- 3) EXIT (seciliyse)
    if md_exit then
        CSleep(200)
        SendPacket(3, "action|join_request\nname|EXIT\ninvitedWorld|0")
        log("`2[MOD] EXIT'e gidildi.")
    end
end

-- Drop (Kulo birebir yontem): isinlan → drop baslat → dialog onayla → geri don
local function Drop(xi, yi, id, count)
    if inv(id) < count then
        overlay("`4Yeterli item yok! Mevcut: "..inv(id))
        return
    end
    -- Su anki pozisyonu kaydet (geri donmek icin)
    local backx = GetLocal().posX
    local backy = GetLocal().posY
    -- 1) Hedef pozisyona isinlan
    tptopos(xi*32, yi*32)
    CSleep(150)
    -- 2) Drop baslat (item elden birakilir)
    SendPacket(2, "action|drop\n|itemID|"..id)
    CSleep(300)
    -- 3) Drop dialogunu onayla (drop_item formati!)
    SendPacket(2, "action|dialog_return\ndialog_name|drop_item\nitemID|"..id.."|\ncount|"..count)
    CSleep(150)
    -- 4) Eski pozisyona geri don
    tptopos(backx, backy)
    log("`2[Drop] "..count.." adet (id:"..id..") → X:"..xi.." Y:"..yi)
end

-- Take (Drop'un tersi): kaydedilen yere isinlan → yerdeki beti topla → geri don
local function take_at(xi, yi)
    -- Su anki pozisyonu kaydet (geri donmek icin)
    local backx = GetLocal().posX
    local backy = GetLocal().posY
    -- 1) Bet noktasina isinlan (sunucu-onayli, drop ile ayni yontem)
    tptopos(xi*32, yi*32)
    CSleep(200)
    -- 2) SADECE o karedeki (xi,yi) itemleri topla
    local count = 0
    local ok, list = pcall(GetObjectList)
    if ok and list then
        for _, obj in pairs(list) do
            if obj.posX and obj.posY
               and math.floor(obj.posX/32) == xi
               and math.floor(obj.posY/32) == yi then
                SendPacketRaw(false, {
                    type  = 11, netid = -1,
                    value = obj.id or obj.uid or obj.oid,
                    x = obj.posX, y = obj.posY
                })
                count = count + 1
            end
        end
    end
    CSleep(150)
    -- 3) Eski pozisyona geri don
    tptopos(backx, backy)
    overlay("`2"..count.." item alindi → geri donuldu.")
    log("`2[Take] "..count.." item (X:"..xi.." Y:"..yi..") → geri")
end

-- Gorsel kiyafeti uygula (sadece istemcide gorunur)
local function apply_clothes()
    -- Kulo birebir slot sirasi: v2={hair,shirt,pants} v3={feet,face,hand} v4={back,mask,neck} v5=skin v6={ances,1,0}
    SendVariant({
        v1 = "OnSetClothing",
        v2 = { cloth.hair, cloth.shirt, cloth.pants },
        v3 = { cloth.feet, cloth.face, cloth.hand },
        v4 = { cloth.back, cloth.hat, cloth.neck },
        v5 = 0.0,
        v6 = { cloth.ances, 1.0, 0.0 }
    }, GetLocal().netID)
    log("`2[Kiyafet] Guncellendi.")
end

-- Toggle dispatch: baloncuklu butona tiklaninca ilgili modu ac/kapat
-- (komutlarla birebir ayni etki, sadece tek yerden)
local function do_toggle(k)
    if     k=="modfly"    then modfly_on=not modfly_on       EditToggle("ModFly",modfly_on)            overlay("`oModFly: "..st(modfly_on))
    elseif k=="ghost"     then ghost_on=not ghost_on         EditToggle("NoClip and Ghost",ghost_on)   overlay("`oGhost: "..st(ghost_on))
    elseif k=="afk"       then afk_on=not afk_on  afk_timer=0                                          overlay("`oAFK: "..st(afk_on))
    elseif k=="autowear"  then autowear_on=not autowear_on                                             overlay("`oAutoWear: "..st(autowear_on))
    elseif k=="pullgas"   then pullgas_on=not pullgas_on                                               overlay("`oPullGas: "..st(pullgas_on))
    elseif k=="banpocket" then banpocket_on=not banpocket_on                                           overlay("`oBanPocket: "..st(banpocket_on))
    elseif k=="blocksdb"  then blocksdb_on=not blocksdb_on                                             overlay("`oBlockSDB: "..st(blocksdb_on))
    elseif k=="checkgems" then checkgems_on=not checkgems_on                                           overlay("`oCheckGems: "..st(checkgems_on))
    elseif k=="fastwheel" then fastwheel_on=not fastwheel_on                                           overlay("`oFastWheel: "..st(fastwheel_on))
    elseif k=="autocbgl"  then autocbgl_on=not autocbgl_on                                             overlay("`oAutoCBGL: "..st(autocbgl_on))
    elseif k=="reme"      then reme_on=not reme_on                                                     overlay("`oREME: "..st(reme_on))
    elseif k=="fastdrop"  then fastdrop_on=not fastdrop_on                                             overlay("`oFastDrop: "..st(fastdrop_on))
    elseif k=="fasttrash" then fasttrash_on=not fasttrash_on                                           overlay("`oFastTrash: "..st(fasttrash_on))
    elseif k=="netid"     then netid_on=not netid_on                                                   overlay("`oNetID: "..st(netid_on))
    elseif k=="moddetect" then moddetect_on=not moddetect_on                                           overlay("`oModDetect: "..st(moddetect_on))
    elseif k=="autoacc"   then autoacc_on=not autoacc_on                                               overlay("`oAuto Access: "..st(autoacc_on))
    elseif k=="hidelevel" then hidelevel_on=not hidelevel_on                                           overlay("`oHide Level: "..st(hidelevel_on))
    elseif k=="pathfind"  then punchtp_on=not punchtp_on                                               overlay("`oPathfind (kar topu): "..st(punchtp_on))
    elseif k=="wrench"    then wrench_on=not wrench_on                                                 overlay("`oWrench: "..st(wrench_on))
    end
end

-- Oyuncu adindan bilgi bul (GetObjectList yok, OnSpawn'den toplanmiyor; manuel arama)
local function find_player_netid(name)
    name = name:lower()
    local players = (GetPlayers and GetPlayers()) or {}
    for _, p in ipairs(players) do
        local pn = (p.name or ""):lower()
        if pn:find(name, 1, true) then return p.netID, p.name end
    end
    return nil
end

local function GetGemsAmount(oid)
    for _, obj in pairs(GetObjectList()) do
        if obj.itemid == 112 and obj.id == oid then return obj.amount end
    end
    return 0
end

-------------------------------------
-- Dialoglar
-------------------------------------
local function build_menu()
    local active = ""
    if modfly_on    then active = active .. "`2Fly " end
    if ghost_on     then active = active .. "`2Ghost " end
    if afk_on       then active = active .. "`2AFK " end
    if pullgas_on   then active = active .. "`2PullGas " end
    if wrench_on    then active = active .. "`2Wrench(" .. wrench_mode .. ") " end
    if fastdrop_on  then active = active .. "`2FDrop " end
    if fasttrash_on then active = active .. "`2FTrash " end
    if netid_on     then active = active .. "`2NetID " end
    if active == "" then active = "`7Yok" end
    return
        "add_label_with_icon|big|`9SYNEX `oPROXY PRO|left|5956|" ..
        "\nadd_smalltext|`7v8.0 • Premium Growtopia Proxy|left|" ..
        "\nadd_spacer|small|" ..
        "\ntext_scaling_string|SynexMenu|" ..
        "\nadd_button_with_icon|tab_drop|`wKilit Dusur|staticBlueFrame|242||" ..
        "\nadd_button_with_icon|tab_pos|`wPozisyon|staticBlueFrame|3524||" ..
        "\nadd_button_with_icon|tab_mods|`wModlar|staticBlueFrame|32||" ..
        "\nadd_button_with_icon||END_LIST|noflags|0||" ..
        "\nadd_button_with_icon|tab_info|`wBilgi|staticBlueFrame|758||" ..
        "\nadd_button_with_icon|tab_csn|`wCSN|staticBlueFrame|4430||" ..
        "\nadd_button_with_icon|tab_general|`wGenel|staticBlueFrame|2586||" ..
        "\nadd_button_with_icon||END_LIST|noflags|0||" ..
        "\nadd_button_with_icon|tab_cloth|`wGorsel Kiyafet|staticBlueFrame|1784||" ..
        "\nadd_button_with_icon||END_LIST|noflags|0||" ..
        "\nadd_spacer|small|" ..
        "\nadd_smalltext|`7Aktif: " .. active .. "|left|" ..
        "\nadd_quick_exit|" ..
        "\nend_dialog|synex_main|Kapat|"
end

local drop_dialog =
    "add_label_with_icon|big|`9Kilit Dusurme|left|242|" ..
    "\nadd_spacer|small|" ..
    "\nadd_textbox|`2Temel Komutlar:|left|758|" ..
    "\nadd_textbox|`o/wd [n] `7• World Lock|left|2440|" ..
    "\nadd_textbox|`o/dd [n] `7• Diamond Lock|left|2440|" ..
    "\nadd_textbox|`o/bd [n] `7• Blue Gem Lock|left|2440|" ..
    "\nadd_textbox|`o/dw [n] `7• DL+WL kombine (105=1DL 5WL)|left|2440|" ..
    "\nadd_spacer|small|" ..
    "\nadd_textbox|`2Hepsini Dusur:|left|758|" ..
    "\nadd_textbox|`o/wall /dall /ball `7• Tek tur hepsi|left|2440|" ..
    "\nadd_textbox|`o/daw `7• Tum kilitleri dusur|left|2440|" ..
    "\nadd_spacer|small|" ..
    "\nadd_textbox|`2Carpan:|left|758|" ..
    "\nadd_textbox|`o/wx2 /wx3 [n] `7• 2x/3x WL|left|2440|" ..
    "\nadd_textbox|`o/dx2 /dx3 [n] `7• 2x/3x DL|left|2440|" ..
    "\nadd_textbox|`o/bx2 /bx3 [n] `7• 2x/3x BGL|left|2440|" ..
    "\nadd_spacer|small|" ..
    "\nadd_button|back_main|`9← Ana Menu|" ..
    "\nadd_quick_exit|" ..
    "\nend_dialog|synex_drop||"

local function build_pos_dialog()
    return
        "add_label_with_icon|big|`9Pozisyon Sistemi|left|3524|" ..
        "\nadd_spacer|small|" ..
        "\nadd_smalltext|`7Pos kaydet → o noktaya drop yap.|left|" ..
        "\nadd_spacer|small|" ..
        "\nadd_textbox|`2Kayitli Pozisyonlar:|left|758|" ..
        "\nadd_textbox|`oPos 1: `9X:"..pos[1][1].." Y:"..pos[1][2].."|left|2440|" ..
        "\nadd_textbox|`oPos 2: `9X:"..pos[2][1].." Y:"..pos[2][2].."|left|2440|" ..
        "\nadd_textbox|`oPos 3: `9X:"..pos[3][1].." Y:"..pos[3][2].."|left|2440|" ..
        "\nadd_textbox|`oPos 4: `9X:"..pos[4][1].." Y:"..pos[4][2].."|left|2440|" ..
        "\nadd_spacer|small|" ..
        "\nadd_textbox|`2Kayit Komutlari:|left|758|" ..
        "\nadd_textbox|`o/ps1 /ps2 /ps3 /ps4 `7• Bulundugun yeri kaydet|left|2440|" ..
        "\nadd_spacer|small|" ..
        "\nadd_textbox|`2Dusurme Komutlari:|left|758|" ..
        "\nadd_textbox|`o/w1..4 [n] `7• WL dusur pozisyona|left|2440|" ..
        "\nadd_textbox|`o/d1..4 [n] `7• DL dusur pozisyona|left|2440|" ..
        "\nadd_textbox|`o/b1..4 [n] `7• BGL dusur pozisyona|left|2440|" ..
        "\nadd_spacer|small|" ..
        "\nadd_textbox|`2Bet Toplama:|left|758|" ..
        "\nadd_textbox|`o/t1..4 `7• O pozisyona git, beti topla, geri don|left|2440|" ..
        "\nadd_spacer|small|" ..
        "\nadd_button|back_main|`9← Ana Menu|" ..
        "\nadd_quick_exit|" ..
        "\nend_dialog|synex_pos||"
end

local function build_mddetect_dialog()
    local function cb(v) return v and "1" or "0" end
    return
        "add_label_with_icon|big|`9Mod Detect Ayarlari|left|758|" ..
        "\nadd_spacer|small|" ..
        "\nadd_textbox|`o@Moderator/Guardian dunyaya girince:|left|2480|" ..
        "\nadd_spacer|small|" ..
        "\nadd_checkbox|md_unaccess|`2Access Birak `7(tum lock'lardan cik)|"..cb(md_unaccess).."|" ..
        "\nadd_checkbox|md_exit|`2EXIT'e Git `7(dunyadan cik)|"..cb(md_exit).."|" ..
        "\nadd_checkbox|md_banall|`4Herkesi Banla `7(RISKLI - dunyadaki herkes)|"..cb(md_banall).."|" ..
        "\nadd_checkbox|md_warn|`2Uyari Ver `7(ekranda goster)|"..cb(md_warn).."|" ..
        "\nadd_checkbox|md_collect|`2Item Topla `7(10 tile - BGL birakma!)|"..cb(md_collect).."|" ..
        "\nadd_spacer|small|" ..
        "\nadd_textbox|`7Mod Tespit: "..st(moddetect_on).." • /md ac /mdoff kapat|left|2480|" ..
        "\nadd_textbox|`7Test icin: /mdtest|left|2480|" ..
        "\nadd_spacer|small|" ..
        "\nadd_button|md_save|`2Kaydet|" ..
        "\nadd_button|back_main|`9← Ana Menu|" ..
        "\nadd_quick_exit|" ..
        "\nend_dialog|synex_mddetect||"
end

local function build_mods_dialog()
    local d = "add_label_with_icon|big|`9Modlar `7(butona tikla = ac/kapat)|left|32|"
    d = d .. "\nadd_spacer|small|"
    -- Durum etiketli tiklanabilir buton (yesil ACIK / kirmizi KAPALI).
    -- buton id'si "tg_<id>" → onSendPacket'te yakalanir, do_toggle cagirir, menu tazelenir.
    local function btn(id, name, icon, state)
        d = d .. "\nadd_button_with_icon|tg_"..id.."|"..(state and "`2" or "`4")..name..": "..st(state).."|staticBlueFrame|"..icon.."||"
    end
    btn("modfly",    "ModFly",       1406, modfly_on)
    btn("ghost",     "Ghost",        5188, ghost_on)
    btn("afk",       "AFK Koruma",   1832, afk_on)
    btn("autowear",  "AutoWear WL",  242,  autowear_on)
    btn("pullgas",   "PullGas",      1486, pullgas_on)
    btn("banpocket", "BanPocket",    5000, banpocket_on)
    btn("blocksdb",  "BlockSDB",     758,  blocksdb_on)
    btn("checkgems", "CheckGems",    112,  checkgems_on)
    btn("fastwheel", "FastWheel",    4430, fastwheel_on)
    btn("autocbgl",  "AutoCBGL",     7188, autocbgl_on)
    btn("reme",      "REME Etiketi", 4430, reme_on)
    btn("fastdrop",  "FastDrop",     1796, fastdrop_on)
    btn("fasttrash", "FastTrash",    4112, fasttrash_on)
    btn("netid",     "NetID Goster", 758,  netid_on)
    btn("moddetect", "Mod Tespit",   32,   moddetect_on)
    btn("autoacc",   "Auto Access",  242,  autoacc_on)
    btn("hidelevel", "Hide Level Msg",758, hidelevel_on)
    btn("pathfind",  "Pathfind (Kar Topu)",1368, punchtp_on)
    -- Wrench: ac/kapat butonu + mod dongu butonu (pull→kick→ban→worldban)
    d = d .. "\nadd_button_with_icon|tg_wrench|"..(wrench_on and "`2" or "`4").."Wrench: "..(wrench_on and ("ACIK `7("..wrench_mode..")") or "KAPALI").."|staticBlueFrame|32||"
    d = d .. "\nadd_button_with_icon|wrench_mode_cycle|`9Wrench Modu → `o"..wrench_mode.."|staticBlueFrame|32||"
    -- Mod Detect alt ayarlari (checkbox'li alt menu, eskisi gibi)
    d = d .. "\nadd_button|open_mddetect|`9⚙ Mod Detect Ayarlari|"
    d = d .. "\nadd_spacer|small|"
    d = d .. "\nadd_smalltext|`7Komutlar hala calisir: /ft /ghost /afk /aw ...|left|"
    d = d .. "\nadd_button|back_main|`9← Ana Menu|"
    d = d .. "\nadd_quick_exit|"
    d = d .. "\nend_dialog|synex_mods||"
    return d
end

local function build_info_dialog()
    local wl    = inv(242)
    local dl    = inv(1796)
    local bgl   = inv(7188)
    local total = wl + dl*100 + bgl*10000
    local x     = math.floor(GetLocal().posX / 32)
    local y     = math.floor(GetLocal().posY / 32)
    return
        "add_label_with_icon|big|`9Bilgi & Envanter|left|758|" ..
        "\nadd_spacer|small|" ..
        "\nadd_textbox|`9World Lock: `o"     ..wl..  "|left|242|" ..
        "\nadd_textbox|`1Diamond Lock: `o"   ..dl..  "|left|1796|" ..
        "\nadd_textbox|`cBlue Gem Lock: `o"  ..bgl.. "|left|7188|" ..
        "\nadd_spacer|small|" ..
        "\nadd_textbox|`2Toplam Bakiye: `9"  ..total.. " WL|left|242|" ..
        "\nadd_textbox|`7Konum: `9X:"        ..x.. " Y:" ..y.."|left|2440|" ..
        "\nadd_textbox|`7Dunya: `9"          ..GetWorldName().."|left|2440|" ..
        "\nadd_spacer|small|" ..
        "\nadd_textbox|`7Komutlar: `o/bal /lock /inv /pos /count [id]|left|" ..
        "\nadd_spacer|small|" ..
        "\nadd_button|back_main|`9← Ana Menu|" ..
        "\nadd_quick_exit|" ..
        "\nend_dialog|synex_info||"
end

local function build_csn_dialog()
    return
        "add_label_with_icon|big|`9CSN Helper|left|4430|" ..
        "\nadd_spacer|small|" ..
        "\nadd_textbox|`2Toplam Kazanc: `9"..csn_earned.. " WL|left|2814|" ..
        "\nadd_textbox|`2Vergi: `9"         ..csn_tax..    "%|left|4430|" ..
        "\nadd_textbox|`2Bahis: `9"         ..csn_bet..    " WL|left|242|" ..
        "\nadd_spacer|small|" ..
        "\nadd_textbox|`7Ayarlar:|left|758|" ..
        "\nadd_textbox|`o/tax [n] `7• Vergi ayarla (%)|left|2440|" ..
        "\nadd_textbox|`o/bet [n] `7• Bahis ayarla (WL)|left|2440|" ..
        "\nadd_spacer|small|" ..
        "\nadd_textbox|`7Kazanan Odemesi:|left|758|" ..
        "\nadd_textbox|`o/win1 `7• Pos1'e vergi dusulmus odeme|left|2440|" ..
        "\nadd_textbox|`o/win2 `7• Pos2'ye vergi dusulmus odeme|left|2440|" ..
        "\nadd_spacer|small|" ..
        "\nadd_button|back_main|`9← Ana Menu|" ..
        "\nadd_quick_exit|" ..
        "\nend_dialog|synex_csn||"
end

local function build_cloth_dialog()
    return
        "add_label_with_icon|big|`9Gorsel Kiyafet|left|1784|" ..
        "\nadd_spacer|small|" ..
        "\nadd_smalltext|`7Sadece SENDE gorunur (fake). Item ID gir.|left|" ..
        "\nadd_spacer|small|" ..
        "\nadd_textbox|`oSapka: `9"..cloth.hat.." `7• /hat [id]|left|2440|" ..
        "\nadd_textbox|`oGomlek: `9"..cloth.shirt.." `7• /shirt [id]|left|2440|" ..
        "\nadd_textbox|`oPantolon: `9"..cloth.pants.." `7• /pants [id]|left|2440|" ..
        "\nadd_textbox|`oAyakkabi: `9"..cloth.feet.." `7• /feet [id]|left|2440|" ..
        "\nadd_textbox|`oYuz: `9"..cloth.face.." `7• /face [id]|left|2440|" ..
        "\nadd_textbox|`oEl: `9"..cloth.hand.." `7• /hand [id]|left|2440|" ..
        "\nadd_textbox|`oSirt (kanat): `9"..cloth.back.." `7• /back [id]|left|2440|" ..
        "\nadd_textbox|`oSac: `9"..cloth.hair.." `7• /hair [id]|left|2440|" ..
        "\nadd_textbox|`oBoyun: `9"..cloth.neck.." `7• /neck [id]|left|2440|" ..
        "\nadd_textbox|`oAnces: `9"..cloth.ances.." `7• /ances [id]|left|2440|" ..
        "\nadd_spacer|small|" ..
        "\nadd_textbox|`4/clothreset `7• Hepsini sifirla|left|2440|" ..
        "\nadd_spacer|small|" ..
        "\nadd_button|back_main|`9← Ana Menu|" ..
        "\nadd_quick_exit|" ..
        "\nend_dialog|synex_cloth||"
end

local function build_general_dialog()
    return
        "add_label_with_icon|big|`9Genel Islemler|left|2586|" ..
        "\nadd_spacer|small|" ..
        "\nadd_textbox|`o/res `7• Respawn|left|2440|" ..
        "\nadd_textbox|`o/relog `7• Relog|left|2440|" ..
        "\nadd_textbox|`o/dc `7• Disconnect|left|2440|" ..
        "\nadd_textbox|`o/rejoin `7• Dunyaya yeniden gir|left|2440|" ..
        "\nadd_textbox|`o/unaccess `7• Tum lock access birak|left|2440|" ..
        "\nadd_textbox|`o/warp [dunya] `7• Belirli dunyaya git|left|2440|" ..
        "\nadd_textbox|`o/name [isim] `7• Gorsel isim | /namereset|left|2440|" ..
        "\nadd_textbox|`o/flag [item id] `7• Bayrak degistir|left|2440|" ..
        "\nadd_textbox|`o/skin [id] `7• Skin rengi degistir|left|2440|" ..
        "\nadd_textbox|`2Title (herkes gorur):|left|758|" ..
        "\nadd_textbox|`o/legend `7• Legendary title|left|2440|" ..
        "\nadd_textbox|`o/mentor `7• Mentor title|left|2440|" ..
        "\nadd_textbox|`o/maxlevel `7• Mavi isim|left|2440|" ..
        "\nadd_textbox|`o/g4g `7• Grow4Good title|left|2440|" ..
        "\nadd_textbox|`o/tp [isim] `7• Oyuncuya isinlan|left|2440|" ..
        "\nadd_textbox|`o/pullall /banall /kickall `7• Toplu wrench|left|2440|" ..
        "\nadd_textbox|`o/proxy_status `7• Tam durum raporu|left|2440|" ..
        "\nadd_spacer|small|" ..
        "\nadd_button|back_main|`9← Ana Menu|" ..
        "\nadd_quick_exit|" ..
        "\nend_dialog|synex_general||"
end

-------------------------------------
-- SendPacket Hook
-------------------------------------
function onSendPacket(type, packet)
    local cp = "action|input\n|text|"

    -- /pkttest acikken: tile/punch metin paketinin tam icerigini dok
    if pkttest_on and (packet:find("tilechangereq") or packet:find("action|tile")) then
        log("`5[TXT] "..packet:gsub("\n"," | "))
    end

    -- Wrench modu: action|wrench paketini yakala (EnetProxy birebir - cift netID)
    if wrench_on and packet:find("action|wrench") then
        local netid = packet:match("netid|(%d+)")
        if netid then
            -- EnetProxy mantigi: cift netID'li popup gonder
            local mode = wrench_mode
            if mode == "ban" then mode = "worldban" end
            SendPacket(2, "action|dialog_return\ndialog_name|popup\nnetID|"..netid.."|\nnetID|"..netid.."|\nbuttonClicked|"..mode)
            wrench_block_next = true  -- gelen oyuncu popup'ini ekranda gizle
            log("`2[Wrench/"..mode.."] → netID: "..netid)
        end
        return false  -- orijinal wrench paketini sunucuya gecir (pull calissin)
    end

    -- Menu
    if packet:find(cp.."/proxy\n") or packet:find(cp.."/proxy$") then
        growtopia.sendDialog(build_menu()) return true
    end

    -- Sekme butonlari
    if packet:find("buttonClicked|tab_drop")    then growtopia.sendDialog(drop_dialog)         return true end
    if packet:find("buttonClicked|tab_pos")     then growtopia.sendDialog(build_pos_dialog())  return true end
    if packet:find("buttonClicked|tab_mods")    then growtopia.sendDialog(build_mods_dialog()) return true end
    if packet:find("buttonClicked|tab_info")    then growtopia.sendDialog(build_info_dialog()) return true end
    if packet:find("buttonClicked|tab_csn")     then growtopia.sendDialog(build_csn_dialog())  return true end
    if packet:find("buttonClicked|tab_general") then growtopia.sendDialog(build_general_dialog()) return true end
    if packet:find("buttonClicked|tab_cloth")   then growtopia.sendDialog(build_cloth_dialog())   return true end
    if packet:find("buttonClicked|back_main")   then growtopia.sendDialog(build_menu())        return true end

    -- Baloncuklu mod butonlari: tikla = aninda ac/kapat, sonra menuyu tazele
    local tgid = packet:match("buttonClicked|tg_(%w+)")
    if tgid then
        do_toggle(tgid)
        growtopia.sendDialog(build_mods_dialog())
        return true
    end

    -- Wrench modunu donguyle degistir (pull → kick → ban → worldban)
    if packet:find("buttonClicked|wrench_mode_cycle") then
        local modes = {"pull","kick","ban","worldban"}
        local idx = 1
        for i, m in ipairs(modes) do if m == wrench_mode then idx = i break end end
        wrench_mode = modes[(idx % #modes) + 1]
        overlay("`2Wrench modu: "..wrench_mode)
        growtopia.sendDialog(build_mods_dialog())
        return true
    end

    -- Mod Detect ayar dialogunu ac
    if packet:find("buttonClicked|open_mddetect") then growtopia.sendDialog(build_mddetect_dialog()) return true end

    -- Mod Detect checkbox'larini kaydet (Kaydet'e basinca dialog_return gelir)
    if packet:find("dialog_name|synex_mddetect") or packet:find("buttonClicked|md_save") then
        -- DEBUG: checkbox ham paketini konsola dok (format gormek icin)
        if dlgtest_on then
            log("`6===== MD CHECKBOX HAM PAKET =====")
            for line in packet:gmatch("[^\n]+") do log("`7"..line) end
            log("`6===== SON =====")
        end
        -- checkbox degerleri pakette "md_unaccess|1" veya "md_unaccess|0" seklinde gelir
        -- Checkbox degeri farkli formatlarda gelebilir: "md_collect|1" veya "md_collect\n1"
        local function cbval(name)
            local v = packet:match(name.."|(%d)") or packet:match(name.."\n(%d)") or packet:match(name.."`(%d)")
            return v == "1"
        end
        md_unaccess = cbval("md_unaccess")
        md_exit     = cbval("md_exit")
        md_banall   = cbval("md_banall")
        md_warn     = cbval("md_warn")
        md_collect  = cbval("md_collect")
        if not moddetect_on then moddetect_on = true end  -- ayar kaydedince otomatik ac
        overlay("`2Mod Detect ayarlari kaydedildi!")
        log("`2[MOD] Ayarlar: unaccess="..tostring(md_unaccess).." exit="..tostring(md_exit).." banall="..tostring(md_banall))
        growtopia.sendDialog(build_menu())
        return true
    end

    -- /proxy_status
    if packet:find(cp.."/proxy_status") then
        log("`6========= DURUM RAPORU =========")
        log("`oModFly:"..st(modfly_on).." Ghost:"..st(ghost_on).." AFK:"..st(afk_on))
        log("`oAutoWear:"..st(autowear_on).." PullGas:"..st(pullgas_on).." BanPocket:"..st(banpocket_on))
        log("`oBlockSDB:"..st(blocksdb_on).." CheckGems:"..st(checkgems_on).." FastWheel:"..st(fastwheel_on))
        log("`oFastDrop:"..st(fastdrop_on).." FastTrash:"..st(fasttrash_on).." AutoCBGL:"..st(autocbgl_on))
        log("`oNetID:"..st(netid_on).." ModDetect:"..st(moddetect_on).." REME:"..st(reme_on))
        log("`oWrench:"..(wrench_on and ("`2ACIK("..wrench_mode..")") or "`4KAPALI"))
        return true
    end

    if packet:find(cp.."/help\n") or packet:find(cp.."/help$") then
        growtopia.sendDialog(build_menu()) return true
    end

    -- Bilgi komutlari
    if packet:find(cp.."/pos\n") or packet:find(cp.."/pos$") then
        local x = math.floor(GetLocal().posX/32)
        local y = math.floor(GetLocal().posY/32)
        log("`6Konum: X:"..x.." Y:"..y)
        overlay("`9X:"..x.."  Y:"..y)
        return true
    end

    if packet:find(cp.."/bal\n") or packet:find(cp.."/bal$") then
        local wl=inv(242) local dl=inv(1796) local bgl=inv(7188)
        local total = wl + dl*100 + bgl*10000
        log("`2Toplam: `9"..total.." WL `o("..bgl.." BGL / "..dl.." DL / "..wl.." WL)")
        overlay("`9Bakiye: "..total.." WL")
        return true
    end

    if packet:find(cp.."/lock\n") or packet:find(cp.."/lock$") then
        log("`9"..inv(242).." WL `o| `1"..inv(1796).." DL `o| `c"..inv(7188).." BGL")
        overlay("`0WL:`9"..inv(242).." `0DL:`1"..inv(1796).." `0BGL:`c"..inv(7188))
        return true
    end

    if packet:find(cp.."/inv\n") or packet:find(cp.."/inv$") then
        log("`9"..inv(242).." WL `o| `1"..inv(1796).." DL `o| `c"..inv(7188).." BGL")
        overlay("`0WL:`9"..inv(242).." `0DL:`1"..inv(1796).." `0BGL:`c"..inv(7188))
        return true
    end

    local cnt = packet:match(cp.."/count (%d+)")
    if cnt then
        local a = inv(tonumber(cnt))
        log("`6ID "..cnt..": "..a.." adet")
        overlay("`9ID "..cnt..": "..a.." adet")
        return true
    end

    -- /apidump - Growlauncher'in fonksiyonlarini konsola dok.
    -- _G icinde path/walk/move/find/nav/goto/tile geceni + tum growtopia.* uyelerini listeler.
    -- Boylece dahili pathfind fonksiyonunun gercek adini buluruz.
    if packet:find(cp.."/apidump\n") or packet:find(cp.."/apidump$") then
        log("`9[API] Global fonksiyonlar (path/walk/move/range/reach/punch/build):")
        local hit = 0
        for k, v in pairs(_G) do
            if _G.type(v) == "function" then
                local lk = tostring(k):lower()
                if lk:find("path") or lk:find("walk") or lk:find("move")
                   or lk:find("find") or lk:find("nav") or lk:find("goto") or lk:find("tile")
                   or lk:find("range") or lk:find("reach") or lk:find("punch") or lk:find("build")
                   or lk:find("hand") or lk:find("dist") or lk:find("long") or lk:find("speed")
                   or lk:find("teleport") or lk:find("warp") or lk:find("edit") or lk:find("set") then
                    log("`2  "..tostring(k)); hit = hit + 1
                end
            end
        end
        if hit == 0 then log("`7  (eslesme yok)") end
        if _G.type(growtopia) == "table" then
            log("`9[API] growtopia.* uyeleri:")
            for k, v in pairs(growtopia) do
                log("`b  growtopia."..tostring(k).." `7(".._G.type(v)..")")
            end
        end
        overlay("`2API listesi konsola yazildi.")
        return true
    end

    -- /pkttest - Cikis ham paketlerinin alan adlarini konsola dok
    -- (pozisyon-drop ve paket alan adlarini bulmak icin)
    if packet:find(cp.."/pkttest\n") or packet:find(cp.."/pkttest$") then
        pkttest_on = not pkttest_on
        overlay(pkttest_on and "`2Paket Test: ACIK! Bir blok kir/koy, sonra yuru." or "`4Paket Test: KAPALI!")
        return true
    end

    -- /dlgtest - Acilan dialoglarin ham icerigini konsola dok (CBGL ayari icin)
    if packet:find(cp.."/dlgtest\n") or packet:find(cp.."/dlgtest$") then
        dlgtest_on = not dlgtest_on
        overlay(dlgtest_on and "`2Dialog Test: ACIK! Telefon/Salesman ac." or "`4Dialog Test: KAPALI!")
        return true
    end

    -- /find [kelime] - Ismine gore esya ID ara (FindItem ile)
    local find_m = packet:match(cp.."/find (.+)")
    if find_m then
        find_m = find_m:gsub("\n", ""):gsub("%s+$", "")
        log("`6'"..find_m.."' araniyor...")
        local found = 0
        -- Growlauncher FindItem(name) item ID dondurur; isim listesi taramasi:
        if FindItem then
            for id = 2, 14000, 2 do
                local ok, name = pcall(GetItemName, id)
                if ok and name and name:lower():find(find_m:lower(), 1, true) then
                    log("`2"..id.." `o- `9"..name)
                    found = found + 1
                    if found >= 30 then log("`4...30+ sonuc, daha spesifik ara.") break end
                end
            end
        end
        if found == 0 then
            log("`4Sonuc yok veya GetItemName desteklenmiyor.")
            overlay("`4'"..find_m.."' bulunamadi.")
        else
            overlay("`2"..found.." sonuc konsola yazildi.")
        end
        return true
    end

    -- CSN
    local tax_m = packet:match(cp.."/tax (%d+)")
    if tax_m then
        csn_tax = math.min(tonumber(tax_m), 100)
        overlay("`2Vergi: "..csn_tax.."%")
        return true
    end
    local bet_m = packet:match(cp.."/bet (%d+)")
    if bet_m then
        csn_bet = tonumber(bet_m)
        overlay("`2Bahis: "..csn_bet.." WL")
        return true
    end

    -- /win1 /win2
    for i = 1, 2 do
        if packet:find(cp.."/win"..i.."\n") or packet:find(cp.."/win"..i.."$") then
            local payout = math.floor(csn_bet * 2 * (100 - csn_tax) / 100)
            csn_earned   = csn_earned + (csn_bet * 2 - payout)
            local dl_out = math.floor(payout / 100)
            local wl_out = payout % 100
            log("`2Odeme → Pos"..i..": `9"..payout.." WL (`9"..dl_out.." DL "..wl_out.." WL`2) Vergi: "..csn_tax.."%")
            ont("`2Kazandi: `9+"..payout.." `2WL")
            if wl_out > 0 then Drop(pos[i][1],pos[i][2],242,wl_out)  CSleep(300) end
            if dl_out > 0 then Drop(pos[i][1],pos[i][2],1796,dl_out) end
            return true
        end
    end

    -- Pozisyon kaydet (once - tek harf komutlardan once)
    for i = 1, 4 do
        if packet:find(cp.."/ps"..i.."\n") or packet:find(cp.."/ps"..i.."$") then
            pos[i][1] = math.floor(GetLocal().posX/32)
            pos[i][2] = math.floor(GetLocal().posY/32)
            overlay("`2Pos "..i.." kaydedildi: X:"..pos[i][1].." Y:"..pos[i][2])
            return true
        end
    end

    -- /wd /dd /bd
    local wd = packet:match(cp.."/wd (%d+)") if wd then smartdrop(242,  tonumber(wd), "World Lock")   return true end
    local dd = packet:match(cp.."/dd (%d+)") if dd then smartdrop(1796, tonumber(dd), "Diamond Lock") return true end
    local bd = packet:match(cp.."/bd (%d+)") if bd then smartdrop(7188, tonumber(bd), "Blue Gem Lock") return true end

    -- /dw
    local dw = packet:match(cp.."/dw (%d+)") if dw then drop_dw(dw) return true end

    -- /daw
    if packet:find(cp.."/daw\n") or packet:find(cp.."/daw$") then
        local wl=inv(242) local dl=inv(1796) local bgl=inv(7188)
        if wl>0  then rdrop(242,  wl)  CSleep(300) end
        if dl>0  then rdrop(1796, dl)  CSleep(300) end
        if bgl>0 then rdrop(7188, bgl) end
        log("`2Tum kilitler dusuruldu.")
        return true
    end

    -- /wall /dall /ball (once - /w /d /b'den once)
    if packet:find(cp.."/wall\n") or packet:find(cp.."/wall$") then smartdrop(242,  inv(242),  "World Lock")   return true end
    if packet:find(cp.."/dall\n") or packet:find(cp.."/dall$") then smartdrop(1796, inv(1796), "Diamond Lock") return true end
    if packet:find(cp.."/ball\n") or packet:find(cp.."/ball$") then smartdrop(7188, inv(7188), "Blue Gem Lock") return true end

    -- Carpanlar (once)
    local wx2=packet:match(cp.."/wx2 (%d+)") if wx2 then smartdrop(242,  tonumber(wx2)*2,"World Lock")   return true end
    local wx3=packet:match(cp.."/wx3 (%d+)") if wx3 then smartdrop(242,  tonumber(wx3)*3,"World Lock")   return true end
    local dx2=packet:match(cp.."/dx2 (%d+)") if dx2 then smartdrop(1796, tonumber(dx2)*2,"Diamond Lock") return true end
    local dx3=packet:match(cp.."/dx3 (%d+)") if dx3 then smartdrop(1796, tonumber(dx3)*3,"Diamond Lock") return true end
    local bx2=packet:match(cp.."/bx2 (%d+)") if bx2 then smartdrop(7188, tonumber(bx2)*2,"Blue Gem Lock") return true end
    local bx3=packet:match(cp.."/bx3 (%d+)") if bx3 then smartdrop(7188, tonumber(bx3)*3,"Blue Gem Lock") return true end

    -- Pozisyona dusurme (once - /w1 vb. /w'den once)
    for i = 1, 4 do
        -- Sayili: "/w1 5"  → 5 adet
        local wm = packet:match(cp.."/w"..i.." (%d+)")
        if wm then
            if pos[i][1]==0 and pos[i][2]==0 then overlay("`4Once /ps"..i.." ile pozisyon kaydet!") return true end
            Drop(pos[i][1],pos[i][2],242,tonumber(wm)) return true
        end
        local dm = packet:match(cp.."/d"..i.." (%d+)")
        if dm then
            if pos[i][1]==0 and pos[i][2]==0 then overlay("`4Once /ps"..i.." ile pozisyon kaydet!") return true end
            Drop(pos[i][1],pos[i][2],1796,tonumber(dm)) return true
        end
        local bm = packet:match(cp.."/b"..i.." (%d+)")
        if bm then
            if pos[i][1]==0 and pos[i][2]==0 then overlay("`4Once /ps"..i.." ile pozisyon kaydet!") return true end
            Drop(pos[i][1],pos[i][2],7188,tonumber(bm)) return true
        end
        -- "/t1..4" → o pozisyona git, beti topla, geri don
        if packet:find(cp.."/t"..i.."\n") or packet:find(cp.."/t"..i.."$") then
            if pos[i][1]==0 and pos[i][2]==0 then overlay("`4Once /ps"..i.." ile pozisyon kaydet!") return true end
            take_at(pos[i][1], pos[i][2]) return true
        end
        -- Sayisiz: "/w1" → miktar gir uyarisi
        if packet:find(cp.."/w"..i.."\n") or packet:find(cp.."/w"..i.."$") then overlay("`4Miktar gir! Ornek: /w"..i.." 5") return true end
        if packet:find(cp.."/d"..i.."\n") or packet:find(cp.."/d"..i.."$") then overlay("`4Miktar gir! Ornek: /d"..i.." 5") return true end
        if packet:find(cp.."/b"..i.."\n") or packet:find(cp.."/b"..i.."$") then overlay("`4Miktar gir! Ornek: /b"..i.." 5") return true end
    end

    -- Genel islemler
    -- /collect veya /ac - Yerdeki itemleri topla (10 tile, Kulo autoc yontemi)
    if packet:find(cp.."/collect\n") or packet:find(cp.."/collect$") or packet:find(cp.."/ac\n") or packet:find(cp.."/ac$") then
        local n = auto_collect()
        overlay("`2"..n.." item toplandi!")
        return true
    end

    -- /unaccess - Tum lock access'lerini birak (Kulo yontemi - mod gelmeden manuel)
    if packet:find(cp.."/unaccess\n") or packet:find(cp.."/unaccess$") then
        SendPacket(2, "action|input\n|text|/unaccess")
        CSleep(300)
        SendPacket(2, "action|dialog_return\ndialog_name|unaccess\nbuttonClicked|Yes")
        overlay("`2Tum access'ler birakildi.")
        log("`2[Unaccess] Tum lock access'leri kaldirildi.")
        return true
    end
    if packet:find(cp.."/res\n")    or packet:find(cp.."/res$")    then SendPacket(2,"action|respawn")                                      overlay("`2Respawn!")                return true end
    if packet:find(cp.."/relog\n")  or packet:find(cp.."/relog$")  then SendPacket(3,"action|quit_to_exit")                                 overlay("`2Relogging...")            return true end
    if packet:find(cp.."/dc\n")     or packet:find(cp.."/dc$")     then SendPacket(3,"action|quit")                                         overlay("`2Disconnected!")           return true end
    if packet:find(cp.."/rejoin\n") or packet:find(cp.."/rejoin$") then SendPacket(3,"action|join_request\nname|"..GetWorldName().."\ninvitedWorld|0")           overlay("`2Rejoin: "..GetWorldName()) return true end

    local warp = packet:match(cp.."/warp (%S+)")
    if warp then SendPacket(3,"action|join_request\nname|"..warp:upper().."\ninvitedWorld|0") overlay("`9Warp → "..warp:upper()) return true end

    -- /name [isim] - Gorsel isim degistir (EnetProxy OnNameChanged yontemi)
    local name_m = packet:match(cp.."/name (.+)")
    if name_m then
        name_m = name_m:gsub("\n", ""):gsub("%s+$", "")
        SendVariant({ v1="OnNameChanged", v2="``"..name_m.."``" }, GetLocal().netID)
        nameset = true
        log("`2Gorsel isim: `9"..name_m)
        return true
    end
    if packet:find(cp.."/namereset\n") or packet:find(cp.."/namereset$") then
        if nameset then
            GetLocal().name = orig_name
            nameset = false
            log("`2Isim eski haline dondu.")
        end
        return true
    end

    -- /flag [item_id] - Bayrak degistir (EnetProxy OnGuildDataChanged yontemi)
    local flag_m = packet:match(cp.."/flag (%d+)")
    if flag_m then
        SendVariant({ v1="OnGuildDataChanged", v2=1, v3=2, v4=tonumber(flag_m) }, GetLocal().netID)
        overlay("`2Bayrak ID: "..flag_m)
        log("`2[Flag] item ID: "..flag_m)
        return true
    end

    -- /skin [id] - Skin rengi degistir
    local skin_m = packet:match(cp.."/skin (%d+)")
    if skin_m then
        SendVariant({ v1="OnChangeSkin", v2=tonumber(skin_m) }, GetLocal().netID)
        overlay("`2Skin degistirildi: "..skin_m)
        return true
    end

    -- ===== GORSEL KIYAFET KOMUTLARI (sadece sende gorunur) =====
    local hat_m   = packet:match(cp.."/hat (%d+)")   if hat_m   then cloth.hat=tonumber(hat_m)     apply_clothes() overlay("`2Sapka: "..hat_m)    return true end
    local shirt_m = packet:match(cp.."/shirt (%d+)") if shirt_m then cloth.shirt=tonumber(shirt_m) apply_clothes() overlay("`2Gomlek: "..shirt_m)  return true end
    local pants_m = packet:match(cp.."/pants (%d+)") if pants_m then cloth.pants=tonumber(pants_m) apply_clothes() overlay("`2Pantolon: "..pants_m) return true end
    local feet_m  = packet:match(cp.."/feet (%d+)")  if feet_m  then cloth.feet=tonumber(feet_m)   apply_clothes() overlay("`2Ayakkabi: "..feet_m) return true end
    local face_m  = packet:match(cp.."/face (%d+)")  if face_m  then cloth.face=tonumber(face_m)   apply_clothes() overlay("`2Yuz: "..face_m)     return true end
    local hand_m  = packet:match(cp.."/hand (%d+)")  if hand_m  then cloth.hand=tonumber(hand_m)   apply_clothes() overlay("`2El: "..hand_m)      return true end
    local back_m  = packet:match(cp.."/back (%d+)")  if back_m  then cloth.back=tonumber(back_m)   apply_clothes() overlay("`2Sirt: "..back_m)    return true end
    local hair_m  = packet:match(cp.."/hair (%d+)")  if hair_m  then cloth.hair=tonumber(hair_m)   apply_clothes() overlay("`2Sac: "..hair_m)     return true end
    local neck_m  = packet:match(cp.."/neck (%d+)")  if neck_m  then cloth.neck=tonumber(neck_m)   apply_clothes() overlay("`2Boyun: "..neck_m)   return true end
    local ances_m = packet:match(cp.."/ances (%d+)") if ances_m then cloth.ances=tonumber(ances_m) apply_clothes() overlay("`2Ances: "..ances_m)  return true end

    -- /clothreset - Tum gorsel kiyafetleri sifirla
    if packet:find(cp.."/clothreset\n") or packet:find(cp.."/clothreset$") then
        cloth = { hat=0, shirt=0, pants=0, feet=0, face=0, hand=0, back=0, hair=0, neck=0, ances=0 }
        apply_clothes()
        overlay("`2Tum gorsel kiyafetler sifirlandi.")
        return true
    end

    -- ===== TITLE KOMUTLARI (Kulo'dan - HERKES gorur) =====
    -- /legend - Isme "of Legend" ekle (Legendary title)
    if packet:find(cp.."/legend\n") or packet:find(cp.."/legend$") then
        local nm = GetLocal().name
        SendVariant({ v1="OnNameChanged", v2="``"..nm.." of Legend``" }, GetLocal().netID)
        log("`2Isim: "..nm.." of Legend")
        overlay("`2Legend title aktif!")
        return true
    end
    -- /mentor - Mentor title
    if packet:find(cp.."/mentor\n") or packet:find(cp.."/mentor$") then
        SendVariant({ v1="OnCountryState", v2="|showGuild|master" }, GetLocal().netID)
        overlay("`2Mentor title aktif!")
        return true
    end
    -- /maxlevel - Mavi isim (Blue Name) title
    if packet:find(cp.."/maxlevel\n") or packet:find(cp.."/maxlevel$") then
        SendVariant({ v1="OnCountryState", v2="us|showGuild|maxLevel" }, GetLocal().netID)
        overlay("`2Max Level (mavi isim) aktif!")
        return true
    end
    -- /g4g - Grow4Good (donor) title
    if packet:find(cp.."/g4g\n") or packet:find(cp.."/g4g$") then
        SendVariant({ v1="OnCountryState", v2="us|showGuild|donor" }, GetLocal().netID)
        overlay("`2Grow4Good title aktif!")
        return true
    end

    -- /tp [isim] - Oyuncuya isinlan (EnetProxy birebir: renk kodunu cikar, bastan eslestir)
    local tp_m = packet:match(cp.."/tp (.+)")
    if tp_m then
        tp_m = tp_m:gsub("\n", ""):gsub("%s+$", ""):lower()
        local found = false
        local players = (GetPlayers and GetPlayers()) or {}
        for _, p in ipairs(players) do
            local pn = (p.name or ""):gsub("^..", ""):lower()  -- ilk 2 karakter renk kodu, cikar
            if pn:find(tp_m, 1, true) == 1 and p.posX then
                SendVariant({ v1="OnSetPos", v2={ p.posX, p.posY } }, GetLocal().netID)
                overlay("`2Isinlandi: "..p.name)
                found = true
                break
            end
        end
        if not found then overlay("`4Oyuncu bulunamadi: "..tp_m) end
        return true
    end

    -- /pullall - Herkesi cek
    if packet:find(cp.."/pullall\n") or packet:find(cp.."/pullall$") then
        local players = (GetPlayers and GetPlayers()) or {}
        local n = 0
        for _, p in ipairs(players) do
            if p.netID ~= GetLocal().netID then
                SendPacket(2, "action|wrench\nnetid|"..p.netID)
                CSleep(30)
                SendPacket(2, "action|dialog_return\ndialog_name|popup\nnetID|"..p.netID.."|\nbuttonClicked|pull")
                n = n + 1
            end
        end
        log("`2"..n.." oyuncu cekildi.")
        return true
    end

    -- /banall - Herkesi banla
    if packet:find(cp.."/banall\n") or packet:find(cp.."/banall$") then
        local players = (GetPlayers and GetPlayers()) or {}
        local n = 0
        for _, p in ipairs(players) do
            if p.netID ~= GetLocal().netID then
                SendPacket(2, "action|wrench\nnetid|"..p.netID)
                CSleep(30)
                SendPacket(2, "action|dialog_return\ndialog_name|popup\nnetID|"..p.netID.."|\nbuttonClicked|worldban")
                n = n + 1
            end
        end
        log("`2"..n.." oyuncu banlandi.")
        return true
    end

    -- /kickall - Herkesi kickle
    if packet:find(cp.."/kickall\n") or packet:find(cp.."/kickall$") then
        local players = (GetPlayers and GetPlayers()) or {}
        local n = 0
        for _, p in ipairs(players) do
            if p.netID ~= GetLocal().netID then
                SendPacket(2, "action|wrench\nnetid|"..p.netID)
                CSleep(30)
                SendPacket(2, "action|dialog_return\ndialog_name|popup\nnetID|"..p.netID.."|\nbuttonClicked|kick")
                n = n + 1
            end
        end
        log("`2"..n.." oyuncu kicklendi.")
        return true
    end

    -- Modlar (off once)
    if packet:find(cp.."/nf\n")      or packet:find(cp.."/nf$")      then EditToggle("ModFly",false)           modfly_on=false    overlay("`4ModFly: KAPALI!")    return true end
    if packet:find(cp.."/ft\n")      or packet:find(cp.."/ft$")      then EditToggle("ModFly",true)            modfly_on=true     overlay("`2ModFly: ACIK!")      return true end
    if packet:find(cp.."/gf\n")      or packet:find(cp.."/gf$")      then EditToggle("NoClip and Ghost",false) ghost_on=false     overlay("`4Ghost: KAPALI!")     return true end
    if packet:find(cp.."/ghost\n")   or packet:find(cp.."/ghost$")   then EditToggle("NoClip and Ghost",true)  ghost_on=true      overlay("`2Ghost: ACIK!")       return true end
    if packet:find(cp.."/afkoff\n")  or packet:find(cp.."/afkoff$")  then afk_on=false  afk_timer=0            overlay("`4AFK: KAPALI!")       return true end
    if packet:find(cp.."/afk\n")     or packet:find(cp.."/afk$")     then afk_on=true   afk_timer=0            overlay("`2AFK: ACIK!")         return true end
    if packet:find(cp.."/awoff\n")   or packet:find(cp.."/awoff$")   then autowear_on=false                    overlay("`4AutoWear: KAPALI!")  return true end
    if packet:find(cp.."/aw\n")      or packet:find(cp.."/aw$")      then autowear_on=true                     overlay("`2AutoWear: ACIK!")    return true end
    if packet:find(cp.."/pgoff\n")   or packet:find(cp.."/pgoff$")   then pullgas_on=false                     overlay("`4PullGas: KAPALI!")   return true end
    if packet:find(cp.."/pg\n")      or packet:find(cp.."/pg$")      then pullgas_on=true                      overlay("`2PullGas: ACIK!")     return true end
    if packet:find(cp.."/bpoff\n")   or packet:find(cp.."/bpoff$")   then banpocket_on=false                   overlay("`4BanPocket: KAPALI!") return true end
    if packet:find(cp.."/bp\n")      or packet:find(cp.."/bp$")      then banpocket_on=true                    overlay("`2BanPocket: ACIK!")   return true end
    if packet:find(cp.."/sdboff\n")  or packet:find(cp.."/sdboff$")  then blocksdb_on=false                    overlay("`4BlockSDB: KAPALI!")  return true end
    if packet:find(cp.."/sdb\n")     or packet:find(cp.."/sdb$")     then blocksdb_on=true                     overlay("`2BlockSDB: ACIK!")    return true end
    if packet:find(cp.."/cgoff\n")   or packet:find(cp.."/cgoff$")   then checkgems_on=false                   overlay("`4CheckGems: KAPALI!") return true end
    if packet:find(cp.."/cg\n")      or packet:find(cp.."/cg$")      then checkgems_on=true                    overlay("`2CheckGems: ACIK!")   return true end
    if packet:find(cp.."/fwoff\n")   or packet:find(cp.."/fwoff$")   then fastwheel_on=false                   overlay("`4FastWheel: KAPALI!") return true end
    if packet:find(cp.."/fw\n")      or packet:find(cp.."/fw$")      then fastwheel_on=true                    overlay("`2FastWheel: ACIK!")   return true end
    if packet:find(cp.."/cbgloff\n") or packet:find(cp.."/cbgloff$") then autocbgl_on=false                    overlay("`4AutoCBGL: KAPALI!")  return true end
    if packet:find(cp.."/cbgl\n")    or packet:find(cp.."/cbgl$")    then autocbgl_on=true                     overlay("`2AutoCBGL: ACIK!")    return true end
    if packet:find(cp.."/remeoff\n") or packet:find(cp.."/remeoff$") then reme_on=false                        overlay("`4REME: KAPALI!")      return true end
    if packet:find(cp.."/reme\n")    or packet:find(cp.."/reme$")    then reme_on=true                         overlay("`2REME: ACIK!")        return true end
    if packet:find(cp.."/fdoff\n")   or packet:find(cp.."/fdoff$")   then fastdrop_on=false                    overlay("`4FastDrop: KAPALI!")  return true end
    if packet:find(cp.."/fd\n")      or packet:find(cp.."/fd$")      then fastdrop_on=true                     overlay("`2FastDrop: ACIK!")    return true end
    if packet:find(cp.."/fttoff\n")  or packet:find(cp.."/fttoff$")  then fasttrash_on=false                   overlay("`4FastTrash: KAPALI!") return true end
    if packet:find(cp.."/ftt\n")     or packet:find(cp.."/ftt$")     then fasttrash_on=true                    overlay("`2FastTrash: ACIK!")   return true end
    if packet:find(cp.."/nidoff\n")  or packet:find(cp.."/nidoff$")  then netid_on=false                       overlay("`4NetID: KAPALI!")     return true end
    if packet:find(cp.."/nid\n")     or packet:find(cp.."/nid$")     then netid_on=true                        overlay("`2NetID: ACIK!")       return true end
    if packet:find(cp.."/mdoff\n")   or packet:find(cp.."/mdoff$")   then moddetect_on=false                   overlay("`4ModDetect: KAPALI!") return true end
    if packet:find(cp.."/mdtest\n")  or packet:find(cp.."/mdtest$")  then
        overlay("`5[TEST] Tum mod tepkileri test ediliyor...")
        log("`5[TEST] Ayarlar → unaccess:"..tostring(md_unaccess).." collect:"..tostring(md_collect).." ban:"..tostring(md_banall).." exit:"..tostring(md_exit))
        trigger_mod_response("TEST")
        return true
    end
    -- /mdtestall - ayarlardan bagimsiz HER SEYI test et (collect dahil)
    if packet:find(cp.."/mdtestall\n") or packet:find(cp.."/mdtestall$") then
        overlay("`5[TEST-ALL] Access + Collect + EXIT zorla test...")
        SendPacket(2, "action|input\n|text|/unaccess")
        CSleep(300)
        SendPacket(2, "action|dialog_return\ndialog_name|unaccess\nbuttonClicked|Yes")
        CSleep(200)
        auto_collect()
        CSleep(200)
        SendPacket(3, "action|join_request\nname|EXIT\ninvitedWorld|0")
        return true
    end
    if packet:find(cp.."/md\n")      or packet:find(cp.."/md$")      then moddetect_on=true                    overlay("`2ModDetect: ACIK!")   return true end
    if packet:find(cp.."/autoaccoff\n") or packet:find(cp.."/autoaccoff$") then autoacc_on=false overlay("`4Auto Access: KAPALI!") return true end
    if packet:find(cp.."/autoacc\n")    or packet:find(cp.."/autoacc$")    then autoacc_on=true  overlay("`2Auto Access: ACIK! Access verilince otomatik kabul.") return true end
    if packet:find(cp.."/hideleveloff\n") or packet:find(cp.."/hideleveloff$") then hidelevel_on=false overlay("`4Hide Level: KAPALI!") return true end
    if packet:find(cp.."/pfoff\n")        or packet:find(cp.."/pfoff$")        then punchtp_on=false overlay("`4Pathfind: KAPALI!") return true end
    if packet:find(cp.."/pf\n")           or packet:find(cp.."/pf$")           then punchtp_on=true  overlay("`2Pathfind ACIK! Kar topunu sec, vurdugun yere isinlan.") return true end
    -- /goto X Y - Growlauncher dahili findPath ile uzaktaki tile'a git (menzil siniri yok)
    local gx, gy = packet:match(cp.."/goto (%d+) (%d+)")
    if gx and gy then
        gx, gy = tonumber(gx), tonumber(gy)
        local ok = pcall(function() return findPath(gx, gy) end)
        if not ok then tptopos(gx*32, gy*32) end  -- findPath yoksa duz isinlan
        overlay("`2Gidiliyor → ("..gx..","..gy..")")
        return true
    end
    if packet:find(cp.."/hidelevel\n")  or packet:find(cp.."/hidelevel$")  then hidelevel_on=true overlay("`2Hide Level: ACIK! Tutorial/Level mesajlari gizli.") return true end
    if packet:find(cp.."/wmoff\n")   or packet:find(cp.."/wmoff$")   then wrench_on=false                      overlay("`4Wrench: KAPALI!")    return true end
    if packet:find(cp.."/wm\n")      or packet:find(cp.."/wm$")      then wrench_on=true                       overlay("`2Wrench: ACIK! ("..wrench_mode..")") return true end

    -- /wms [mod]
    for _, m in ipairs({"pull","kick","ban","worldban"}) do
        if packet:find(cp.."/wms "..m) then
            wrench_mode = m
            overlay("`2Wrench modu: "..m)
            return true
        end
    end

    return false
end

-------------------------------------
-- Variant Hook
-------------------------------------
function onVariant(var)
    if not var.v1 then return false end

    -- Dialog test modu: ham icerigi konsola dok
    if dlgtest_on and var.v1 == "OnDialogRequest" and var.v2 then
        log("`6===== DIALOG HAM =====")
        -- uzun olabilir, parca parca yaz
        local s = var.v2
        for i = 1, #s, 180 do
            log("`7" .. s:sub(i, i+179))
        end
        log("`6===== SON =====")
        -- engelleme, dialog normal acilsin
    end

    -- BlockSDB
    if var.v1 == "OnSDBroadcast" and blocksdb_on then
        return true
    end

    -- AutoCBGL (hem telephone hem phonecall yontemi denenir)
    if autocbgl_on and var.v1 == "OnDialogRequest" and var.v2 then
        local dlg = var.v2
        local x = dlg:match("|x|(%d+)") or dlg:match("tilex|(%d+)")
        local y = dlg:match("|y|(%d+)") or dlg:match("tiley|(%d+)")
        if dlg:find("Phone #") or dlg:find("Dial a number") or dlg:find("phonecall") then
            -- Yontem 1: telephone + bglconvert (IfanHelper)
            if x and y then
                SendPacket(2, "action|dialog_return\ndialog_name|telephone\nx|"..x.."|\ny|"..y.."|\nnum|53785|\nbuttonClicked|bglconvert")
            end
            -- Yontem 2: phonecall + dial (LuckyProxy)
            SendPacket(2, "action|dialog_return\ndialog_name|phonecall\ndial|53785\nbuttonClicked|chc0")
            log("`2[CBGL] 53785 convert gonderildi.")
            return true
        elseif dlg:find("Excellent%!") then
            local num = dlg:match("num|%-(%d+)")
            if x and y and num then
                SendPacket(2, "action|dialog_return\ndialog_name|telephone\nx|"..x.."|\ny|"..y.."|\nnum|-"..num.."|\nbuttonClicked|bglconvert")
                wear(7188)
                log("`2[CBGL] BGL alindi ve giyildi!")
            end
            return true
        end
    end
    if var.v1 == "OnDialogRequest" and var.v2 then
        local dlg = var.v2

        -- Wrench popup'unu engelle (wrench_on acikken): hem tile WrenchMenu'su
        -- hem de oyuncu popup'i (Trade/Send Message...). Pull yine de gerceklesir.
        if wrench_on and wrench_block_next and
           (dlg:find("WrenchMenu") or dlg:find("Send Message")
            or dlg:find("buttonClicked|trade") or dlg:find("end_dialog|popup")) then
            wrench_block_next = false
            return true
        end

        -- FastDrop
        if fastdrop_on and dlg:find("drop_item") then
            local itemid = dlg:match("embed_data|itemID|(%d+)") or dlg:match("itemID|(%d+)")
            local count  = dlg:match("count||(%d+)")
            if itemid and count then
                SendPacket(2,"action|dialog_return\ndialog_name|drop_item\nitemID|"..itemid.."|\ncount|"..count)
                return true
            end
        end

        -- FastTrash
        if fasttrash_on and (dlg:find("Trash") or dlg:find("trash_item")) then
            local itemid = dlg:match("embed_data|itemID|(%d+)") or dlg:match("itemID|(%d+)")
            local count  = dlg:match("you have (%d+)") or dlg:match("count||(%d+)")
            if itemid and count then
                SendPacket(2,"action|dialog_return\ndialog_name|trash_item\nitemID|"..itemid.."|\ncount|"..count)
                log("`2[FastTrash] "..count.." adet silindi.")
                return true
            end
        end

        -- Kilit drop dialogunu engelle (fastdrop kapaliyken)
        if not fastdrop_on and dlg:find("drop") then
            if dlg:find("|242|") or dlg:find("|1796|") or dlg:find("|7188|") then
                return true
            end
        end
    end

    -- NetID Display (OnSpawn)
    if netid_on and var.v1 == "OnSpawn" and var.v2 then
        local netid = var.v2:match("netID|(%d+)")
        if netid then
            local modified = var.v2:gsub("(name|[^|\n]+)", "%1 `4["..netid.."]``", 1)
            SendVariant({ v1="OnSpawn", v2=modified })
            return true
        end
    end

    -- FastWheel
    if fastwheel_on and var.v1 == "OnTalkBubble" and var.v3 and var.v3:find("spun the wheel") then
        SendVariant({ v1="OnTalkBubble", v2=var.v2, v3="````"..var.v3, v4=var.v4 })
        return true
    end

    -- PullGas
    if pullgas_on and var.v1 == "OnTalkBubble" and var.v3 and var.v3:find("gas") then
        SendPacket(2,"action|dialog_return\ndialog_name|popup\nnetID|"..tostring(var.v2).."|\nbuttonClicked|pull")
        return true
    end

    -- BanPocket
    if banpocket_on and var.v1 == "OnTalkBubble" and var.v3 and var.v3:find("`4MWAHAHAHA!! FIRE FIRE FIRE") then
        SendPacket(2,"action|dialog_return\ndialog_name|popup\nnetID|"..tostring(var.v2).."|\nbuttonClicked|worldban")
        overlay("`2Atese veren ban yedi!")
        return true
    end

    -- Hide Level / Tutorial mesajlari (/hidelevel)
    if hidelevel_on then
        if var.v1 == "OnTalkBubble" and var.v3 and (var.v3:find("You need to be") or var.v3:find("to break this")) then
            return true
        end
        if var.v1 == "OnConsoleMessage" and var.v2 and (var.v2:find("You need to be") or var.v2:find("tutorial")) then
            return true
        end
        if var.v1 == "OnDialogRequest" and var.v2 and var.v2:find("tutorial") then
            return true
        end
    end
    -- (eski) You need to be engelle - hidelevel kapaliyken de spam engelle
    if var.v1 == "OnTalkBubble" and var.v3 and var.v3:find("You need to be") then
        return true
    end

    -- Auto Access (/autoacc) - access verilince otomatik kabul
    if autoacc_on and var.v1 == "OnDialogRequest" and var.v2 then
        if var.v2:find("acceptaccess") or var.v2:find("give you access") or var.v2:find("wants to give") then
            local btn = var.v2:match("buttonClicked|([%w_]+)") or "acceptaccess"
            SendPacket(2, "action|dialog_return\ndialog_name|acceptaccess\nbuttonClicked|"..btn)
            log("`2[Auto Access] Access otomatik kabul edildi.")
            return true
        end
    end

    -- REME + [REAL/GERCEK]
    if reme_on and var.v1 == "OnTalkBubble" and var.v3 and var.v3:find("spun the wheel and got") then
        local spun_str = var.v3:match("`4(%d+)``!") or var.v3:match("`b(%d+)``!") or var.v3:match("`2(%d+)``!")
        if spun_str then
            local spun = tonumber(spun_str)
            if spun then
                local reme = (math.floor(spun/10) + spun%10) % 10
                SendVariant({
                    v1 = "OnTalkBubble",
                    v2 = var.v2,
                    v3 = "`2[REAL/GERCEK] `o"..var.v3.." `2[ `9REME: `w"..reme.." `2]"
                })
                return true
            end
        end
    end

    -- OnConsoleMessage islemleri
    if var.v1 == "OnConsoleMessage" and var.v2 then
        local msg = var.v2

        -- AutoWear
        if msg:match("Collected `w%d+ World Lock``") then
            if autowear_on then wear(242) log("`2[AutoWear] WL giyildi.") end
            return true
        end

        -- Ziyaretci bildirimi
        local visitor = msg:match("`w(.+)`` connected")
        if visitor then
            log("`e[Ziyaretci] "..visitor.." girdi!")
            overlay("`e"..visitor.." dunyaya girdi!")
        end

        -- Mod Tespit
        if moddetect_on then
            if msg:find("moderator") or msg:find("Moderator") or msg:find("GROWTOPIA MODERATOR") then
                trigger_mod_response("Konsol mesaji")
                return true
            end
        end
    end

    -- AFK Koruma
    if afk_on then
        afk_timer = afk_timer + 1
        if afk_timer >= 800 then
            SendPacket(2,"action|respawn")
            afk_timer = 0
            log("`5[AFK] Otomatik respawn.")
        end
    end

    return false
end

-------------------------------------
-- SendPacketRaw Hook (CheckGems)
-------------------------------------
function onSendPacketRaw(pkt)
    -- /pkttest acikken: paketin hangi alanlari dolu, konsola yaz.
    -- Boylece punch hedef koordinatinin alan adini buluruz.
    if pkttest_on then
        local cand = {"type","netid","value","flags","x","y","int_x","int_y",
                      "pos_x","pos_y","punchX","punchY","vec_x","vec_y",
                      "vec2_x","vec2_y","item_id","itemid","jump","jump_amount",
                      "tilex","tiley","intx","inty","px","py","posx","posy",
                      "targetx","targety","tile_x","tile_y","bx","by","block_x","block_y","item"}
        -- Hedef tasiyan paketleri dok: type 3 (tile) VEYA px/py dolu (>=0) olanlar.
        -- Bos hareket paketlerini (px=-1) atlar; kar atisini yakalar.
        local ok0, t = pcall(function() return pkt.type end)
        local okp, ppx = pcall(function() return pkt.px end)
        local interesting = (ok0 and t == 3) or (okp and ppx and ppx >= 0) or (ok0 and t ~= 0 and t ~= nil)
        if interesting then
            local line = "`6[PKT t="..tostring(t).."] "
            for _, f in ipairs(cand) do
                if f ~= "type" then
                    local ok, v = pcall(function() return pkt[f] end)
                    if ok and v ~= nil then line = line .. "`o"..f.."`7="..tostring(v).."  " end
                end
            end
            log(line)
        end
    end

    -- Pathfind: punchtp_on iken kar topunu (punchtp_item) attigin tam (px,py)'ye git.
    -- Kodda mesafe siniri YOK; px/py kar topunun dustugu tile. tptopos ile tam oraya isinla.
    if punchtp_on and pkt.type == 3 and pkt.value == punchtp_item then
        local okx, px = pcall(function() return pkt.px end)
        local oky, py = pcall(function() return pkt.py end)
        if okx and oky and px and py and px >= 0 and py >= 0 then
            tptopos(px * 32, py * 32)
            overlay("`2Pathfind → ("..px..","..py..")")
            return true  -- atisi bloke et: kar harcama, sadece git
        end
    end

    if checkgems_on then
        if pkt.type == 11 then
            table.insert(OIDList, pkt.value)
        elseif pkt.type == 0 and #OIDList > 0 then
            for _, oid in pairs(OIDList) do
                Gems = Gems + GetGemsAmount(oid)
            end
            if Gems > 0 then ont("`9+"..Gems.." `2Gem") end
            Gems = 0
            OIDList = {}
        end
    end
    return false
end

-------------------------------------
-- Baslangic + SYNEX Acilis Efekti
-------------------------------------
runCoroutine(function()
    CSleep(800)
    -- Harf harf acilan SYNEX yazisi
    local letters = {"`4S", "`8Y", "`eN", "`2E", "`bX"}
    local built = ""
    for i = 1, #letters do
        built = built .. letters[i]
        overlay(built)
        CSleep(180)
    end
    CSleep(400)
    -- Renk dalgasi efekti (SYNEX yazisi renk degistiriyor)
    local waves = {
        "`4S`8Y`eN`2E`bX",
        "`bS`4Y`8N`eE`2X",
        "`2S`bY`4N`8E`eX",
        "`eS`2Y`bN`4E`8X",
        "`8S`eY`2N`bE`4X"
    }
    for i = 1, #waves do
        overlay(waves[i])
        CSleep(150)
    end
    CSleep(300)
    -- Final
    overlay("`4S`8Y`eN`2E`bX `7PROXY")
    CSleep(700)
    overlay("`2Yuklendi! `7→ `o/proxy")
    CSleep(200)

    sendDialog(welcome)
    log("`4S`8Y`eN`2E`bX `7PROXY PRO v8 yuklendi! → `/proxy")
end)

AddHook(onSendPacket,    "OnSendPacket")
AddHook(onVariant,       "OnVariant")
AddHook(onSendPacketRaw, "OnSendPacketRaw")
