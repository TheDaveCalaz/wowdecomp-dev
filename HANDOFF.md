# Handoff: modern AddOns on the decompiled 3.3.5a client

Read this first in a new session. Branch `modern-addons` in `TheDaveCalaz/wowdecomp-dev`. The latest commit is 2536a51; CI run 40109422701 passed. Dave has not yet tested this build.

## The goal

Dave's own words:

> I want the new decompclient to natively load retail style addons that work without any extras as if I am installing an addon for retail or one of the modern WoW clients.

This covers retail, modern and Wrath Classic (3.4.x, 2022) addons. Never fix one addon at a time. Every fix goes in the client: either the C++ engine or the built-in Lua layer in `WoW/Source/UIUtil/ModernUI/`.

## Working rules

**Writing to Dave:**
- British English.
- Concise, prose rather than bullet lists.
- Don't build features he hasn't asked for.

**Data and files:**
- Never store the database password.
- Ask before writing to the server's dbc folder or database.
- Back up anything you replace.

**Commits:**
- Author: `-c user.name=Dave -c user.email=188569689+TheDaveCalaz@users.noreply.github.com`.
- End the message with the `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` line and the session line (`Claude-Session: ...`).

**CI:**
- Push, then find the run: `gh run list -R TheDaveCalaz/wowdecomp-dev -b modern-addons -L 1`.
- Wait with an until-loop on `gh run view <id> --json status,conclusion`.
- Give Dave the run link.
- The artefact is `wowclient-x64-<sha>`.
- To name crash addresses, add `.github/crash-addresses.txt` on a branch made at that commit; CI's "Name crash addresses" step reports them.

**Dave's machine (linked through the desktop app):**
- Logs: `D:\WowDecompTest\Logs\LuaErrors.log` and `FrameXML.log`.
- AddOns: `D:\WowDecompTest\Interface\AddOns\`.
- Copy files over with the device stage-files tool. There is no shell on his machine. Each new session starts with "ModernUI player at load", so read the log from the last such line.

**Tests:**
- Run with `cd WoW/Source/UIUtil/ModernUI/tests && python3 run.py <test>.lua` for test, test_guard, test_map, test_mapcanvas, test_panels, test_scrollbox, test_surface and test_objects. All pass.
- Compile-check every Lua file with lupa `loadstring`.
- For C++, use `g++ -fsyntax-only` with `-DSTORMAPI=` and similar defines; errors about MSVC-only code are expected.

## How the layer is built

Lua files in `ModernUI/` load in file-name order after FrameXML and before any addon (`GameUI.cpp` calls `ModernUI_Load`). The XML templates load after the Lua.

**Generated files.** Regenerate these with their tools; never edit them by hand:

| File | Tool | What it holds |
|---|---|---|
| `95_ApiSurface.lua` | `tools/gen_surface.py <docs_merged>:<retail docs> out tools/gen_runtime.lua` | The documented API, Wrath Classic first with retail filling the gaps. Return kind `{Type}` means an object made by `ModernUI_CreateObject` |
| `96_BlizzardShared.lua` | `tools/gen_import.py` | Blizzard shared Lua. Run with `RETAIL_ADDONS=<live AddOns>` and the arguments `Blizzard_SharedXMLBase Blizzard_SharedXML/Blizzard_SharedXML_Wrath.toc Blizzard_FrameXMLBase/Blizzard_FrameXMLBase_Wrath.toc retail:Blizzard_SharedXMLBase retail:Blizzard_Colors retail:Blizzard_SharedXML retail:Blizzard_FrameXMLBase retail:Blizzard_FrameXMLUtil retail:Blizzard_ChatFrameBase/Shared/ChatFrameConstants.lua retail:Blizzard_ChatFrameBase/Shared/ChatTypeInfoConstants.lua retail:Blizzard_ChatFrameBase/Shared/ChatFrameUtil.lua` |
| `11_EnumUndocumented.lua` | `gen_enum_undoc.py` | Enums the documentation lacks |
| `12_BlizzardConstants.lua` | `gen_constants.py` | Blizzard constants |
| `13_RetailOnlyNamespaces.lua` | `gen_retail_only.py` | Namespaces only retail has |
| `35_ModernFrameNames.lua` | `gen_modern_frames.py` | Modern Blizzard frame names |
| `94_UndocumentedAPI.lua` | `gen_undocumented.py` | Undocumented globals and C_ functions |
| `97_BlizzardFunctionStubs.lua` | `gen_blizzard_stubs.py` | No-op stand-ins for Blizzard functions |

**Inputs these tools need:**
- Blizzard UI sources at `/tmp/claude-0/wowui/{classic_titan,live}/Interface/AddOns`. These are not in the repo; extract them again from the Wrath Classic 3.80 and retail 12.1 UI exports if they are missing.
- 3.3.5 API JSON at `scratchpad/AddonScanner/api_335.json`.
- Merged documentation at `scratchpad/docs_merged`.
- ElvUI source: `git clone https://github.com/tukui-org/ElvUI`.

**Key hand-written files:**
- `35_Objects.lua`: real curves, colour curves, durations and number formatters.
- `36_FrameAliases.lua`: modern frame names point to 3.3.5 frames. Missing modern frames become hidden stand-ins on first lookup through `_G`'s metatable. `ScriptErrorsFrame` always exists.
- `34_ModelScene.lua`: ModelScene actors built on PlayerModel.
- `33_SecureAuraHeader.lua`: ported from Wrath Classic; its template is in `91_BlizzardTemplates.xml`.
- `98_AddOnEnvironment.lua`: two environments. Modern addons use `ModernUI_AddOnEnvironment`. Addons whose .toc lists a Classic version use `ModernUI_ClassicAddOnEnvironment`, which hides the retail-only namespaces. The C++ side chooses between them in `AddOns.cpp` (`m_classicInterface`) and `FrameScript.cpp`.
- `99_UnknownAPI.lua`: unknown C_ functions and Enum groups are created on first use and logged as "ModernUI: ... is not known".

**Engine changes this session:**
- Mask textures (`Frame/ModernUIMask.cpp`): composed images that are powers of two, solid colours, logging.
- Draw sub-levels: regions are ordered by sub-level then creation, and `CRenderBatch::Finish` no longer sorts.
- FreeType upgraded to 2.13.3 in `ThirdParty/freetype`, so OTF fonts work.
- Spellbook functions accept a spell ID on its own (`SpellBookFrame.cpp` `GetSlotFromLua`).
- `GetCameraZoom` returns the zoom the camera is heading to.
- The over-the-shoulder camera shift moves the look-at point too (`Camera.cpp` `ModernUI_ShoulderShift`).
- .toc metadata lines honour `[AllowLoadGameType]`.
- `SetBackdrop()` with no argument works.

## Status from Dave's last test (build 6a2a0c3)

**Working:** Narcissus (masks, the name and the zoom are now right), DBM, Questie's map and tracker, and WeakAuras loads.

**Fixed in 2536a51 but not yet tested:**
- ElvUI set no fonts: `CanBeAccessedInContext` returned false.
- Modern frames ElvUI looks for (StatusTrackingBarManager, BagsBar, EmbeddedItemTooltip, PVPReadyDialog, ReportFrame, TableAttributeDisplay) now get stand-ins.
- SecureAuraHeaderTemplate.
- BugGrabber now gets ScriptErrorsFrame, so BugSack should find it.
- DialogueUI's `CreateActor`.
- Hekili's `GetTotemInfo` slots.
- MountJournalEnhanced's `C_Garrison` check, now hidden for Classic-flavour addons.
- Narcissus's character position, through the shoulder look-at fix.

**Open:**
- **Plater popup:** the "Plater vs ElvUI nameplates" popup's buttons don't respond to clicks. Ask Dave for an `/fstack` over a button; it may be an overlay.
- **Questie:** "Tooltip.lua:75 name nil" and "Missing objective data" for quests 967, 993 and 10752 persist after a database recompile. Questie's raw data includes those NPCs, so the cause could be in the client (compiled-database decoding) or a mismatch with the server's quest data. Not yet traced.
- **ElvUI:** check the next layer of errors after this build. Known gaps: WorldMapFrame.BlackoutFrame, children of existing Blizzard frames, and AceHook targets in DebugTools.
- **Mount and pet journals:** Dave asked to port them. The plan is to build C_MountJournal and C_PetJournal on 3.3.5 companions (`GetCompanionInfo("MOUNT"/"CRITTER")`), then import Wrath Classic's Blizzard_Collections UI. Not started.
- **Bagnon:** check whether the button icons now appear reliably (the sub-level and sort fix should cover it). The bottom-right frame piece was missing.
- **DialogueUI options window:** blank.

## Next step

Ask Dave to test the build from CI run 40109422701 (artefact `wowclient-x64-2536a51`). Then read the logs from the last "ModernUI player at load" line and fix by category, never per addon.
