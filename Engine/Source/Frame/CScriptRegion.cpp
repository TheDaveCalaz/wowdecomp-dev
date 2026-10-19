#include <cstddef>
#include <cstdint>
#include <cstring>
#include "Engine/Source/Frame/CScriptRegion.h"
#include "Engine/Source/Base/Coordinate.h"
#include "Engine/Source/Base/Status.h"
#include "Engine/Source/Frame/CSimpleAlphaAnim.h"
#include "Engine/Source/Frame/CSimpleAnimGroup.h"
#include "Engine/Source/Frame/CSimpleFrame.h"
#include "Engine/Source/Frame/CSimpleTop.h"
#include "Engine/Source/FrameScript/FrameScript.h"
#include "Engine/Source/FrameXML/LoadXML.h"
#include "Engine/Source/FrameXML/XMLTree.h"
#include "Engine/Source/Storm/H/storm.h"
#include "Engine/Source/Tempest/CRect.h"
#include "Engine/Source/lua-5.1/src/lua.h"

// STATIC: 0x00B49978
int32_t CScriptRegion::s_objectType;

// STATIC: 0x00AC0FB0
const char* CScriptRegion::s_objectTypeName = "Region";

// INLINED
int32_t CScriptRegion::GetObjectType() {
    if (!CScriptRegion::s_objectType) {
        CScriptRegion::s_objectType = ++FrameScript_Object::s_objectTypes;
    }

    return CScriptRegion::s_objectType;
}

// VERIFY: 7bfc2639 auto
// OFFSET: 0x00482B40
CScriptObject* CScriptRegion::GetScriptObjectParent() {
    return this->m_parent;
}

// VERIFY: 35de1b9a auto
// OFFSET: 0x00482B50
bool CScriptRegion::IsA(int32_t type) {
    return type == CScriptRegion::s_objectType || type == CScriptObject::s_objectType;
}

// VERIFY: 25d91e66 auto
// OFFSET: 0x00482B80
bool CScriptRegion::IsA(const char* typeName) {
    return !SStrCmpI(typeName, CScriptRegion::s_objectTypeName, STORM_MAX_STR) || !SStrCmpI(typeName, CScriptObject::s_objectTypeName, STORM_MAX_STR);
}

// VERIFY: 0eb6bce3 auto
// OFFSET: 0x004881C0
const char* CScriptRegion::GetObjectTypeName() {
    return CScriptRegion::s_objectTypeName;
}

// VERIFY: c4694f97 manual
// OFFSET: 0x00488310
CScriptRegion::CScriptRegion() {
    this->m_parent = nullptr;
    this->m_animGroups = nullptr;
    this->m_playingAnimGroups = nullptr;
}

// VERIFY: 59f5e1dd manual
// OFFSET: 0x00488350
bool CScriptRegion::IsDragging() {
    return this->m_parent ? this->m_parent->IsDragging() : false;
}

// VERIFY: e4b70ae0 auto
// OFFSET: 0x004883A0
void CScriptRegion::SetParent(CSimpleFrame* parent) {
    this->m_parent = parent;
}

// VERIFY: 2e5f1acc manual
// OFFSET: 0x004883F0
void CScriptRegion::LoadXML_Animations(XMLNode* node, CStatus* status) {
    XMLNode* animations = node->GetChildByName("Animations");

    if (!animations) {
        return;
    }

    for (XMLNode* child = animations->m_child; child; child = child->m_next) {
        if (SStrCmpI(child->m_name.m_str, "AnimationGroup", STORM_MAX_STR)) {
            const char* name = this->GetName();
            status->Add(STATUS_WARNING, "%s %s: Unknown child node in %s element: %s", this->GetObjectTypeName(), name ? name : "<unnamed>", animations->m_name.m_str, child->m_name.m_str);
        } else {
            LoadXML_AnimGroup(child, this, status);
        }
    }
}

// VERIFY: 1c1c5c31 manual
// OFFSET: 0x004884B0
CLayoutFrame* CScriptRegion::GetLayoutParent() {
    CLayoutFrame* parent = this->m_parent;
    return parent ? parent : CSimpleTop::s_instance;
}

// VERIFY: c93d6a9b manual
// OFFSET: 0x004884D0
CLayoutFrame* CScriptRegion::GetLayoutFrameByName(const char* name) {
    char fullName[1024];
    this->CreateName(name, fullName, sizeof(fullName));

    CScriptRegion* region = static_cast<CScriptRegion*>(CScriptObject::GetScriptObjectByName(fullName, CScriptRegion::GetObjectType()));
    return region;
}

// ModernUI: walks a key path from this region: "$parent" steps to the parent, any other part reads
// that key from the current object's Lua table ("$parent.$parent.Title", "$parent.ScrollBar").
CLayoutFrame* CScriptRegion::GetLayoutFrameByKey(const char* path) {
    lua_State* L = FrameScript_GetContext();
    CScriptObject* current = this;
    char part[256];
    const char* cursor = path;
    int32_t top = lua_gettop(L);

    while (cursor && *cursor && current) {
        const char* dot = SStrChr(cursor, '.');
        size_t length = dot ? static_cast<size_t>(dot - cursor) : SStrLen(cursor);

        if (length >= sizeof(part)) {
            current = nullptr;
            break;
        }

        memcpy(part, cursor, length);
        part[length] = '\0';
        cursor = dot ? dot + 1 : nullptr;

        if (!part[0]) {
            continue;
        }

        if (!SStrCmpI(part, "$parent", STORM_MAX_STR)) {
            current = current->GetScriptObjectParent();
            continue;
        }

        if (!current->m_luaRegistered) {
            current->RegisterScriptObject(nullptr);
        }

        lua_rawgeti(L, LUA_REGISTRYINDEX, current->m_luaObjectRef);

        if (!lua_istable(L, -1)) {
            current = nullptr;
            break;
        }

        lua_getfield(L, -1, part);

        if (!lua_istable(L, -1)) {
            current = nullptr;
            break;
        }

        lua_rawgeti(L, -1, 0);
        current = static_cast<CScriptObject*>(lua_touserdata(L, -1));
        lua_settop(L, top);
    }

    lua_settop(L, top);

    if (!current || !current->IsA(CScriptRegion::GetObjectType())) {
        return nullptr;
    }

    return static_cast<CScriptRegion*>(current);
}

// VERIFY: 6a00f6bb manual
// OFFSET: 0x00488540
bool CScriptRegion::ProtectedFunctionsAllowed() {
    return !this->IsProtected() || !lua_tainted || CSimpleTop::s_instance->m_allowProtectedActions != 0;
}

// VERIFY: 5c7fa85d auto
// OFFSET: 0x00488570
bool CScriptRegion::IsMouseOver(float top, float bottom, float left, float right) {
    CSimpleTop* simpleTop = CSimpleTop::s_instance;

    if (!simpleTop) {
        return false;
    }

    if (this->IsResizePending()) {
        this->Resize(1);
    }

    CRect rect = { 0.0f, 0.0f, 0.0f, 0.0f };

    if (!this->GetRect(&rect)) {
        return false;
    }

    float ddcX = 0.0f;
    float ddcY = 0.0f;
    NDCToDDC(simpleTop->m_mousePosition.m_x, simpleTop->m_mousePosition.m_y, &ddcX, &ddcY);

    float x = 1.0f / this->m_layoutScale * ddcX;
    float y = 1.0f / this->m_layoutScale * ddcY;
    float scale = 1.0f / this->m_layoutScale;

    return rect.minX * scale + left < x && rect.maxX * scale + right > x && scale * rect.minY + bottom < y && scale * rect.maxY + top > y;
}

// VERIFY: 6702c0a1 manual
// OFFSET: 0x00488670
void CScriptRegion::LoadXML(XMLNode* node, CStatus* status) {
    CLayoutFrame::LoadXML(node, status);

    const char* parentKey = node->GetAttributeByName("parentKey");

    if (parentKey && *parentKey) {
        lua_State* L = FrameScript_GetContext();
        CScriptObject* parent = this->GetScriptObjectParent();

        if (parent) {
            if (!parent->m_luaRegistered) {
                parent->RegisterScriptObject(nullptr);
            }

            lua_rawgeti(L, LUA_REGISTRYINDEX, parent->m_luaObjectRef);
            lua_pushstring(L, parentKey);

            if (!this->m_luaRegistered) {
                this->RegisterScriptObject(nullptr);
            }

            lua_rawgeti(L, LUA_REGISTRYINDEX, this->m_luaObjectRef);
            lua_settable(L, -3);
            lua_settop(L, -2);
        }
    }

    this->LoadXML_Modern(node, status);
    this->LoadXML_Animations(node, status);
}

// Not in the original client: modern XML attributes and elements.
//   mixin="A, B" / secureMixin="A"  copy the named Lua tables' fields onto the object (before OnLoad)
//   parentArray="Name"              append the object to parent.Name
//   <KeyValues><KeyValue key="k" value="v" type="string|number|boolean|global|nil" keyType="string|number"/>
//                                   set fields on the object
// Templates are loaded through here too, so what a template declares applies to everything inheriting it.
void CScriptRegion::LoadXML_Modern(XMLNode* node, CStatus* status) {
    const char* mixin = node->GetAttributeByName("mixin");
    const char* secureMixin = node->GetAttributeByName("secureMixin");
    const char* parentArray = node->GetAttributeByName("parentArray");
    XMLNode* keyValues = node->GetChildByName("KeyValues");

    if (!(mixin && *mixin) && !(secureMixin && *secureMixin) && !(parentArray && *parentArray) && !keyValues) {
        return;
    }

    lua_State* L = FrameScript_GetContext();

    if (!this->m_luaRegistered) {
        this->RegisterScriptObject(nullptr);
    }

    int32_t top = lua_gettop(L);
    lua_rawgeti(L, LUA_REGISTRYINDEX, this->m_luaObjectRef);
    int32_t self = lua_gettop(L);

    for (const char* list : { mixin, secureMixin }) {
        if (!list || !*list) {
            continue;
        }

        char name[256];
        const char* cursor = list;

        do {
            SStrTokenize(&cursor, name, sizeof(name), " ,", nullptr);

            if (!name[0]) {
                break;
            }

            lua_pushstring(L, name);
            lua_rawget(L, LUA_GLOBALSINDEX);

            if (lua_istable(L, -1)) {
                lua_pushnil(L);

                while (lua_next(L, -2)) {
                    lua_pushvalue(L, -2);
                    lua_insert(L, -2);
                    lua_settable(L, self);
                }
            } else {
                const char* objectName = this->GetName();
                status->Add(STATUS_WARNING, "%s: Unknown mixin %s", objectName ? objectName : "<unnamed>", name);
            }

            lua_pop(L, 1);
        } while (name[0]);
    }

    if (keyValues) {
        for (XMLNode* child = keyValues->m_child; child; child = child->m_next) {
            if (SStrCmpI(child->m_name.m_str, "KeyValue", STORM_MAX_STR)) {
                continue;
            }

            const char* key = child->GetAttributeByName("key");
            const char* value = child->GetAttributeByName("value");
            const char* type = child->GetAttributeByName("type");
            const char* keyType = child->GetAttributeByName("keyType");

            if (!key || !*key) {
                continue;
            }

            if (keyType && !SStrCmpI(keyType, "number", STORM_MAX_STR)) {
                lua_pushnumber(L, SStrToFloat(key));
            } else {
                lua_pushstring(L, key);
            }

            if (!type || !*type || !SStrCmpI(type, "string", STORM_MAX_STR)) {
                lua_pushstring(L, value ? value : "");
            } else if (!SStrCmpI(type, "number", STORM_MAX_STR)) {
                lua_pushnumber(L, value ? SStrToFloat(value) : 0.0);
            } else if (!SStrCmpI(type, "boolean", STORM_MAX_STR)) {
                lua_pushboolean(L, value && !SStrCmpI(value, "true", STORM_MAX_STR));
            } else if (!SStrCmpI(type, "global", STORM_MAX_STR)) {
                lua_pushstring(L, value ? value : "");
                lua_rawget(L, LUA_GLOBALSINDEX);
            } else {
                lua_pushnil(L);
            }

            lua_settable(L, self);
        }
    }

    if (parentArray && *parentArray) {
        CScriptObject* parent = this->GetScriptObjectParent();

        if (parent) {
            if (!parent->m_luaRegistered) {
                parent->RegisterScriptObject(nullptr);
            }

            lua_rawgeti(L, LUA_REGISTRYINDEX, parent->m_luaObjectRef);
            int32_t parentTable = lua_gettop(L);
            lua_pushstring(L, parentArray);
            lua_rawget(L, parentTable);

            if (!lua_istable(L, -1)) {
                lua_pop(L, 1);
                lua_newtable(L);
                lua_pushstring(L, parentArray);
                lua_pushvalue(L, -2);
                lua_rawset(L, parentTable);
            }

            // Append unless this object is already in the array (a template and its user both naming it).
            bool present = false;
            int32_t count = static_cast<int32_t>(lua_objlen(L, -1));

            for (int32_t i = 1; i <= count && !present; i++) {
                lua_rawgeti(L, -1, i);
                present = lua_rawequal(L, -1, self) != 0;
                lua_pop(L, 1);
            }

            if (!present) {
                lua_pushvalue(L, self);
                lua_rawseti(L, -2, count + 1);
            }
        }
    }

    lua_settop(L, top);
}

// VERIFY: 23893fb6 auto
// OFFSET: 0x00488740
int32_t CScriptRegion::HasActiveAnimGroup() {
    for (CScriptRegion* region = this; region; region = region->m_parent) {
        if (region->m_playingAnimGroups && region->m_playingAnimGroups->Head()) {
            return 1;
        }
    }

    return 0;
}

// VERIFY: 0d8bdeba manual
// OFFSET: 0x00488770
int32_t CScriptRegion::HasActiveAnimOfType(int32_t type) {
    for (CScriptRegion* region = this; region; region = region->m_parent) {
        if (region->m_playingAnimGroups && region->m_playingAnimGroups->Head()) {
            for (CSimpleAnimGroup* group = region->m_playingAnimGroups->Head(); group; group = region->m_playingAnimGroups->Next(group)) {
                if (group->HasAnimOfType(type)) {
                    return 1;
                }
            }
        }
    }

    return 0;
}

// VERIFY: cd671bd7 manual
// OFFSET: 0x004887F0
void CScriptRegion::GetActiveAnimInfo(int32_t type, int32_t& active, int32_t& activeOfType) {
    active = 0;
    activeOfType = 0;

    for (CScriptRegion* region = this; region; region = region->m_parent) {
        if (region->m_playingAnimGroups && region->m_playingAnimGroups->Head()) {
            active = 1;

            for (CSimpleAnimGroup* group = region->m_playingAnimGroups->Head(); group; group = region->m_playingAnimGroups->Next(group)) {
                if (group->HasAnimOfType(type)) {
                    activeOfType = 1;
                    break;
                }
            }
        }
    }
}

// VERIFY: 1fdc6a93 manual
// OFFSET: 0x00488890
void CScriptRegion::OnAnimUpdate(float elapsedSec) {
    if (!this->m_animGroups) {
        return;
    }

    for (CSimpleAnimGroup* group = this->m_animGroups->Head(); group; group = this->m_animGroups->Next(group)) {
        group->OnUpdate(elapsedSec);
    }
}

// VERIFY: a1b47d00 manual
// OFFSET: 0x004888F0
void CScriptRegion::StopAnimating() {
    if (!this->m_playingAnimGroups) {
        return;
    }

    for (CSimpleAnimGroup* group = this->m_playingAnimGroups->Head(); group; group = this->m_playingAnimGroups->Next(group)) {
        group->Stop(true);
    }
}

// VERIFY: 21de8cdf auto
// OFFSET: 0x00488980
void CScriptRegion::NotifyAnimEnd(CSimpleAnimGroup* group) {
    if (!group || !this->m_playingAnimGroups) {
        return;
    }

    this->m_playingAnimGroups->UnlinkNode(group);
    this->AnimDeactivated(group, !this->HasActiveAnimGroup());
}

// VERIFY: 3973d91a manual
// OFFSET: 0x004889C0
void CScriptRegion::NotifyAnimBegin(CSimpleAnimGroup* group) {
    if (!group) {
        return;
    }

    if (!this->m_playingAnimGroups) {
        this->m_playingAnimGroups = new (SMemAlloc(sizeof(*this->m_playingAnimGroups), __FILE__, __LINE__, 0)) TSExplicitList<CSimpleAnimGroup, offsetof(CSimpleAnimGroup, m_playingLink)>;

        if (!this->m_playingAnimGroups) {
            return;
        }
    }

    this->AnimActivated(group, !this->HasActiveAnimGroup(), group->HasAnimOfType(CSimpleAlphaAnim::GetObjectType()));
    this->m_playingAnimGroups->LinkToTail(group);
}

// VERIFY: 5d173137 manual
// OFFSET: 0x00488AE0
void CScriptRegion::RegisterAnimGroup(CSimpleAnimGroup* group) {
    if (!group) {
        return;
    }

    if (!this->m_animGroups) {
        this->m_animGroups = new (SMemAlloc(sizeof(*this->m_animGroups), __FILE__, __LINE__, 0)) TSExplicitList<CSimpleAnimGroup, offsetof(CSimpleAnimGroup, m_regionLink)>;
    }

    if (this->m_animGroups) {
        this->m_animGroups->LinkToTail(group);
    }
}

// VERIFY: 37e65262 manual
// OFFSET: [0x00488370, 0x00488B50, 0x00488BB0]
CScriptRegion::~CScriptRegion() {
    if (this->m_animGroups) {
        this->m_animGroups->Clear();
        delete this->m_animGroups;
    }

    if (this->m_playingAnimGroups) {
        delete this->m_playingAnimGroups;
    }
}

// VERIFY: 4d845176 manual
// OFFSET: 0x005EEB70
void CScriptRegion::PreOnAnimUpdate() {
}

// VERIFY: c64042c5 auto
// OFFSET: 0x0047ADD0
void CScriptRegion::AnimActivated(CSimpleAnimGroup* group, int32_t first, int32_t hasAlpha) {
}

// VERIFY: 83a5621b auto
// OFFSET: 0x00653A10
void CScriptRegion::AnimDeactivated(CSimpleAnimGroup* group, int32_t last) {
}

// VERIFY: 3b0fa002 auto
// OFFSET: 0x00632050
void CScriptRegion::AddAnimTranslation(const C2Vector& translation) {
}

// VERIFY: 3cc88c19 auto
// OFFSET: 0x0047ADD0
void CScriptRegion::AddAnimRotation(FRAMEPOINT origin, const C2Vector& offset, float radians) {
}

// VERIFY: 3b3ba4d8 auto
// OFFSET: 0x0047ADD0
void CScriptRegion::AddAnimScale(FRAMEPOINT origin, const C2Vector& offset, const C2Vector& scale) {
}

// VERIFY: db7e550e auto
// OFFSET: 0x00632050
void CScriptRegion::AddAnimAlpha(int16_t alpha) {
}
