// Not in the original client: mask textures, as modern clients draw them.
//
// A mask limits where a texture shows: the texture keeps its colour and takes the mask's alpha, over the area
// where the two overlap on screen (outside the mask nothing shows). This client's renderer draws each texture
// with one image, so a masked texture is drawn with an image composed for it: its own texels (the part its
// texture coordinates show) with the alpha multiplied by each mask's, sampled where the mask lies over it.
// Compositions are kept, keyed by the images, texture coordinates and the masks' places relative to the texture,
// so moving a masked frame around costs nothing; a mask that moves relative to its texture makes a new one.

#include "Engine/Source/Frame/ModernUIMask.h"
#include <cmath>
#include <cstdio>
#include <string>
#include <unordered_map>
#include <vector>
#include "Engine/Source/Base/Handle.h"
#include "Engine/Source/Frame/CScriptObject.h"
#include "Engine/Source/Frame/CSimpleFrame.h"
#include "Engine/Source/Frame/CSimpleTexture.h"
#include "Engine/Source/FrameScript/FrameScript.h"
#include "Engine/Source/FrameXML/XMLTree.h"
#include "Engine/Source/Gx/CGxTex.h"
#include "Engine/Source/Services/Texture.h"
#include "Engine/Source/Services/TextureImage.h"
#include "Engine/Source/Storm/H/storm.h"
#include "Engine/Source/Tempest/CRect.h"
#include "Engine/Source/lua-5.1/src/lua.h"

namespace {

std::unordered_map<const CSimpleTexture*, std::vector<CSimpleTexture*>> s_masks;

struct Image {
    bool loaded = false;
    bool valid = false;
    bool hasAlpha = false;
    uint32_t width = 0;
    uint32_t height = 0;
    std::vector<uint8_t> bgra;
};

std::unordered_map<std::string, Image> s_images;

// Problems go to Logs\LuaErrors.log, once each, so a mask that cannot be drawn can be traced.
void LogOnce(const std::string& message) {
    static std::unordered_map<std::string, bool> s_logged;

    if (s_logged.size() < 200 && !s_logged[message]) {
        s_logged[message] = true;
        FrameScript_LogError(message.c_str());
    }
}

const Image& LoadImage(const char* name) {
    std::string key = name ? name : "";
    Image& image = s_images[key];

    if (!image.loaded) {
        image.loaded = true;
        image.valid = !key.empty() && ModernUI_DecodeTextureFile(key.c_str(), image.width, image.height, image.bgra);

        if (!image.valid && !key.empty() && SStrCmpI(key.c_str(), "SolidTexture", STORM_MAX_STR)) {
            LogOnce("ModernUI masks: could not read the image " + key);
        }

        if (image.valid) {
            for (size_t i = 3; i < image.bgra.size(); i += 4) {
                if (image.bgra[i] != 0xFF) {
                    image.hasAlpha = true;
                    break;
                }
            }
        }
    }

    return image;
}

struct Composed {
    CTexture* texture = nullptr;
    std::vector<std::vector<uint8_t>> levels;
    std::vector<uint32_t> widths;
    std::vector<uint32_t> heights;
};

std::unordered_map<std::string, Composed*> s_composed;
std::unordered_map<const CTexture*, Composed*> s_byTexture;
const size_t MAX_COMPOSED = 1024;

void UpdateComposed(EGxTexCommand command, uint32_t width, uint32_t height, uint32_t face, uint32_t level, void* userArg, uint32_t& texelStrideInBytes, const void*& texels) {
    auto found = s_byTexture.find(static_cast<CTexture*>(userArg));

    if (found == s_byTexture.end() || command != GxTex_Latch) {
        return;
    }

    Composed* composed = found->second;
    size_t index = level < composed->levels.size() ? level : composed->levels.size() - 1;
    texelStrideInBytes = 4 * composed->widths[index];
    texels = composed->levels[index].data();
}

// A full cache (a masked texture that keeps changing size makes a new image each time) starts again. The images
// are kept one round longer, as a texture drawn this frame may still be queued.
std::vector<Composed*> s_retired;

void FreeComposed(Composed* composed) {
    if (composed->texture) {
        s_byTexture.erase(reinterpret_cast<CTexture*>(composed->texture));
        HandleClose(reinterpret_cast<HOBJECT>(composed->texture));
    }

    delete composed;
}

void RetireComposed() {
    for (Composed* composed : s_retired) {
        FreeComposed(composed);
    }

    s_retired.clear();

    for (auto& entry : s_composed) {
        if (entry.second) {
            s_retired.push_back(entry.second);
        }
    }

    s_composed.clear();
}

// Bilinear interpolation of the four corners (top left, bottom left, top right, bottom right).
inline void Corner(const C2Vector* corners, float u, float v, float& x, float& y) {
    float topX = corners[0].x + (corners[2].x - corners[0].x) * u;
    float topY = corners[0].y + (corners[2].y - corners[0].y) * u;
    float bottomX = corners[1].x + (corners[3].x - corners[1].x) * u;
    float bottomY = corners[1].y + (corners[3].y - corners[1].y) * u;
    x = topX + (bottomX - topX) * v;
    y = topY + (bottomY - topY) * v;
}

inline const uint8_t* Sample(const Image& image, float s, float t) {
    float fs = s - std::floor(s);
    float ft = t - std::floor(t);

    if (s >= 0.0f && s <= 1.0f) {
        fs = s;
    }

    if (t >= 0.0f && t <= 1.0f) {
        ft = t;
    }

    int32_t x = static_cast<int32_t>(fs * image.width);
    int32_t y = static_cast<int32_t>(ft * image.height);
    x = x < 0 ? 0 : (x >= static_cast<int32_t>(image.width) ? image.width - 1 : x);
    y = y < 0 ? 0 : (y >= static_cast<int32_t>(image.height) ? image.height - 1 : y);
    return &image.bgra[(static_cast<size_t>(y) * image.width + x) * 4];
}

const char* FileOf(CSimpleTexture* texture) {
    if (!texture || !texture->m_texture) {
        return "";
    }

    const char* name = TextureGetFilename(texture->m_texture);
    return name ? name : "";
}

void Append(std::string& key, float value) {
    char buffer[32];
    snprintf(buffer, sizeof(buffer), "%.3f,", value);
    key += buffer;
}

struct MaskPlace {
    const Image* image;
    C2Vector texCoords[4];
    float left, top, width, height; // relative to the texture: 0..1 across it
};

void BuildLevels(Composed* composed, uint32_t width, uint32_t height, std::vector<uint8_t>&& base) {
    composed->levels.push_back(std::move(base));
    composed->widths.push_back(width);
    composed->heights.push_back(height);

    while (composed->widths.back() > 1 || composed->heights.back() > 1) {
        uint32_t srcW = composed->widths.back();
        uint32_t srcH = composed->heights.back();
        const std::vector<uint8_t>& src = composed->levels.back();
        uint32_t dstW = srcW > 1 ? srcW / 2 : 1;
        uint32_t dstH = srcH > 1 ? srcH / 2 : 1;
        std::vector<uint8_t> dst(static_cast<size_t>(dstW) * dstH * 4);

        for (uint32_t y = 0; y < dstH; y++) {
            for (uint32_t x = 0; x < dstW; x++) {
                uint32_t x0 = x * 2 < srcW ? x * 2 : srcW - 1;
                uint32_t x1 = x * 2 + 1 < srcW ? x * 2 + 1 : x0;
                uint32_t y0 = y * 2 < srcH ? y * 2 : srcH - 1;
                uint32_t y1 = y * 2 + 1 < srcH ? y * 2 + 1 : y0;

                for (uint32_t c = 0; c < 4; c++) {
                    uint32_t sum = src[(y0 * srcW + x0) * 4 + c] + src[(y0 * srcW + x1) * 4 + c] + src[(y1 * srcW + x0) * 4 + c] + src[(y1 * srcW + x1) * 4 + c];
                    dst[(static_cast<size_t>(y) * dstW + x) * 4 + c] = static_cast<uint8_t>((sum + 2) / 4);
                }
            }
        }

        composed->levels.push_back(std::move(dst));
        composed->widths.push_back(dstW);
        composed->heights.push_back(dstH);
    }
}

CTexture* MakeTexture(Composed* composed, uint32_t id) {
    CTexture* texture = new ("HTEXTURE", SLOG_OBJECT) CTexture;

    if (!texture) {
        return nullptr;
    }

    texture->m_alphaBits = 8;
    SStrPrintf(texture->m_filename, sizeof(texture->m_filename), "ModernUIMaskedTexture%u", id);
    s_byTexture[texture] = composed;
    texture->m_gxTex = TextureAllocGxTex(GxTex_2d, composed->widths[0], composed->heights[0], 0, GxTex_Argb8888, CGxTexFlags(), texture, UpdateComposed, GxTex_Argb8888, texture->m_filename);

    if (!texture->m_gxTex) {
        s_byTexture.erase(texture);
        texture->~CTexture();
        SMemFree(texture, __FILE__, __LINE__, 0);
        return nullptr;
    }

    texture->m_gxTexTarget = GxTex_2d;
    texture->m_gxWidth = static_cast<uint16_t>(composed->widths[0]);
    texture->m_gxHeight = static_cast<uint16_t>(composed->heights[0]);
    return reinterpret_cast<CTexture*>(HandleCreate(texture, "HTEXTURE"));
}

// Lua object table -> its texture region, or nullptr.
CSimpleTexture* TextureFromLua(lua_State* L, int32_t index) {
    if (lua_type(L, index) != LUA_TTABLE) {
        return nullptr;
    }

    lua_rawgeti(L, index, 0);
    CScriptObject* object = static_cast<CScriptObject*>(lua_touserdata(L, -1));
    lua_settop(L, -2);

    if (!object || !object->IsA(CSimpleTexture::GetObjectType())) {
        return nullptr;
    }

    return static_cast<CSimpleTexture*>(object);
}

struct PendingMask {
    CSimpleFrame* frame;
    CSimpleTexture* mask;
    std::vector<std::string> keys;
};

std::vector<PendingMask> s_pending;

} // namespace

void ModernUI_AddMask(CSimpleTexture* texture, CSimpleTexture* mask) {
    if (!texture || !mask || texture == mask) {
        return;
    }

    std::vector<CSimpleTexture*>& list = s_masks[texture];

    for (CSimpleTexture* existing : list) {
        if (existing == mask) {
            return;
        }
    }

    list.push_back(mask);
}

void ModernUI_RemoveMask(CSimpleTexture* texture, CSimpleTexture* mask) {
    auto found = s_masks.find(texture);

    if (found == s_masks.end()) {
        return;
    }

    std::vector<CSimpleTexture*>& list = found->second;

    for (size_t i = 0; i < list.size(); i++) {
        if (list[i] == mask) {
            list.erase(list.begin() + i);
            break;
        }
    }

    if (list.empty()) {
        s_masks.erase(found);
    }
}

void ModernUI_ForgetMaskTexture(CSimpleTexture* texture) {
    for (size_t i = 0; i < s_pending.size();) {
        if (s_pending[i].mask == texture) {
            s_pending.erase(s_pending.begin() + i);
        } else {
            i++;
        }
    }

    if (s_masks.empty()) {
        return;
    }

    s_masks.erase(texture);

    for (auto it = s_masks.begin(); it != s_masks.end();) {
        std::vector<CSimpleTexture*>& list = it->second;

        for (size_t i = 0; i < list.size();) {
            if (list[i] == texture) {
                list.erase(list.begin() + i);
            } else {
                i++;
            }
        }

        it = list.empty() ? s_masks.erase(it) : std::next(it);
    }
}

bool ModernUI_HasMasks(const CSimpleTexture* texture) {
    return !s_masks.empty() && s_masks.count(texture) != 0;
}

CTexture* ModernUI_MaskedTexture(CSimpleTexture* texture) {
    auto found = s_masks.find(texture);

    if (found == s_masks.end() || found->second.empty()) {
        return nullptr;
    }

    CRect rect;

    if (!texture->GetRect(&rect) || rect.maxX <= rect.minX || rect.maxY <= rect.minY) {
        return nullptr;
    }

    float width = rect.maxX - rect.minX;
    float height = rect.maxY - rect.minY;

    const char* sourceName = FileOf(texture);
    std::string key = sourceName;
    key += '|';

    // A colour texture (SetColorTexture, <Color>) is an 8x8 image of one colour, kept with its CGxTex.
    Image solid;

    if (!SStrCmpI(sourceName, "SolidTexture", STORM_MAX_STR) && texture->m_texture->m_gxTex) {
        uint32_t bgra = static_cast<uint32_t>(reinterpret_cast<uintptr_t>(texture->m_texture->m_gxTex->m_userArg));
        solid.loaded = solid.valid = true;
        solid.width = solid.height = 1;
        solid.bgra = { static_cast<uint8_t>(bgra), static_cast<uint8_t>(bgra >> 8), static_cast<uint8_t>(bgra >> 16), static_cast<uint8_t>(bgra >> 24) };
        solid.hasAlpha = solid.bgra[3] != 0xFF;
        char colour[16];
        snprintf(colour, sizeof(colour), "%08x|", bgra);
        key += colour;
    }

    for (const C2Vector& tc : texture->m_texCoords) {
        Append(key, tc.x);
        Append(key, tc.y);
    }

    std::vector<MaskPlace> places;

    for (CSimpleTexture* mask : found->second) {
        const char* maskName = FileOf(mask);
        const Image& maskImage = LoadImage(maskName);

        if (!maskImage.valid) {
            continue;
        }

        CRect maskRect;

        if (mask->IsResizePending()) {
            mask->Resize(1); // masks are hidden, so their layout is otherwise left pending
        }

        if (!mask->GetRect(&maskRect) || maskRect.maxX <= maskRect.minX || maskRect.maxY <= maskRect.minY) {
            maskRect = rect;
        }

        MaskPlace place;
        place.image = &maskImage;
        mask->GetTexCoord(place.texCoords);
        place.left = (maskRect.minX - rect.minX) / width;
        place.top = (rect.maxY - maskRect.maxY) / height;
        place.width = (maskRect.maxX - maskRect.minX) / width;
        place.height = (maskRect.maxY - maskRect.minY) / height;
        places.push_back(place);

        key += '|';
        key += maskName;
        key += '|';

        for (const C2Vector& tc : place.texCoords) {
            Append(key, tc.x);
            Append(key, tc.y);
        }

        Append(key, place.left);
        Append(key, place.top);
        Append(key, place.width);
        Append(key, place.height);
    }

    if (places.empty()) {
        return nullptr;
    }

    auto cached = s_composed.find(key);

    if (cached != s_composed.end()) {
        return cached->second ? cached->second->texture : nullptr;
    }

    if (s_composed.size() >= MAX_COMPOSED) {
        RetireComposed();
    }

    const Image& source = solid.valid ? solid : LoadImage(sourceName);
    bool sizeFromSource = source.valid && !solid.valid;

    // The size of the composition: the source texels the texture shows, or the first mask's when the texture
    // has no image of its own (a colour).
    float spanU = std::fabs(texture->m_texCoords[2].x - texture->m_texCoords[0].x) + std::fabs(texture->m_texCoords[1].x - texture->m_texCoords[0].x);
    float spanV = std::fabs(texture->m_texCoords[1].y - texture->m_texCoords[0].y) + std::fabs(texture->m_texCoords[2].y - texture->m_texCoords[0].y);
    const Image& sizing = sizeFromSource ? source : *places[0].image;
    uint32_t outW = static_cast<uint32_t>(sizing.width * (sizeFromSource ? (spanU > 0.0f ? spanU : 1.0f) : places[0].width ? 1.0f / places[0].width : 1.0f));
    uint32_t outH = static_cast<uint32_t>(sizing.height * (sizeFromSource ? (spanV > 0.0f ? spanV : 1.0f) : places[0].height ? 1.0f / places[0].height : 1.0f));
    outW = outW < 8 ? 8 : (outW > 512 ? 512 : outW);
    outH = outH < 8 ? 8 : (outH > 512 ? 512 : outH);

    std::vector<uint8_t> texels(static_cast<size_t>(outW) * outH * 4);

    for (uint32_t oy = 0; oy < outH; oy++) {
        float v = (oy + 0.5f) / outH;

        for (uint32_t ox = 0; ox < outW; ox++) {
            float u = (ox + 0.5f) / outW;
            uint8_t* out = &texels[(static_cast<size_t>(oy) * outW + ox) * 4];

            if (source.valid) {
                float s;
                float t;
                Corner(texture->m_texCoords, u, v, s, t);
                const uint8_t* texel = Sample(source, s, t);
                out[0] = texel[0];
                out[1] = texel[1];
                out[2] = texel[2];
                out[3] = texel[3];
            } else {
                out[0] = out[1] = out[2] = out[3] = 0xFF;
            }

            uint32_t alpha = out[3];

            for (const MaskPlace& place : places) {
                float mu = (u - place.left) / place.width;
                float mv = (v - place.top) / place.height;

                if (mu < 0.0f || mu > 1.0f || mv < 0.0f || mv > 1.0f) {
                    alpha = 0;
                    break;
                }

                float s;
                float t;
                Corner(place.texCoords, mu, mv, s, t);
                const uint8_t* texel = Sample(*place.image, s, t);
                uint32_t maskAlpha = place.image->hasAlpha ? texel[3] : texel[2];
                alpha = alpha * maskAlpha / 255;
            }

            out[3] = static_cast<uint8_t>(alpha);
        }
    }

    Composed* composed = new Composed();
    BuildLevels(composed, outW, outH, std::move(texels));
    composed->texture = MakeTexture(composed, static_cast<uint32_t>(s_composed.size()) + 1);

    if (!composed->texture) {
        LogOnce(std::string("ModernUI masks: could not make the masked image for ") + sourceName);
        delete composed;
        s_composed[key] = nullptr;
        return nullptr;
    }

    s_composed[key] = composed;
    return composed->texture;
}

void ModernUI_NoteXMLMask(CSimpleFrame* frame, CSimpleTexture* mask, XMLNode* node) {
    if (!frame || !mask || !node) {
        return;
    }

    PendingMask pending;
    pending.frame = frame;
    pending.mask = mask;

    for (XMLNode* child = node->m_child; child; child = child->m_next) {
        if (SStrCmpI(child->m_name.m_str, "MaskedTextures", STORM_MAX_STR)) {
            continue;
        }

        for (XMLNode* masked = child->m_child; masked; masked = masked->m_next) {
            const char* key = masked->GetAttributeByName("childKey");

            if (key && *key) {
                pending.keys.push_back(key);
            }
        }
    }

    if (!pending.keys.empty()) {
        s_pending.push_back(std::move(pending));
    }
}

void ModernUI_ResolveXMLMasks(CSimpleFrame* frame) {
    if (s_pending.empty()) {
        return;
    }

    lua_State* L = FrameScript_GetContext();

    for (size_t i = 0; i < s_pending.size();) {
        PendingMask& pending = s_pending[i];

        if (pending.frame != frame) {
            i++;
            continue;
        }

        if (!frame->m_luaRegistered) {
            // Keys live in the frame's Lua table, so a frame without one has none to find.
            s_pending.erase(s_pending.begin() + i);
            continue;
        }

        for (const std::string& key : pending.keys) {
            int32_t top = lua_gettop(L);
            lua_rawgeti(L, LUA_REGISTRYINDEX, frame->m_luaObjectRef);

            // "Icon", "Border.Icon", "$parent.Icon"
            size_t start = 0;

            while (start <= key.size() && lua_type(L, -1) == LUA_TTABLE) {
                size_t dot = key.find('.', start);
                std::string part = key.substr(start, dot == std::string::npos ? std::string::npos : dot - start);

                if (part == "$parent") {
                    lua_getfield(L, -1, "GetParent");

                    if (lua_isfunction(L, -1)) {
                        lua_pushvalue(L, -2);

                        if (lua_pcall(L, 1, 1, 0)) {
                            lua_pushnil(L);
                        }
                    }
                } else {
                    lua_getfield(L, -1, part.c_str());
                }

                if (dot == std::string::npos) {
                    break;
                }

                start = dot + 1;
            }

            CSimpleTexture* texture = TextureFromLua(L, -1);

            if (texture) {
                ModernUI_AddMask(texture, pending.mask);
            } else {
                LogOnce("ModernUI masks: <MaskedTexture childKey=\"" + key + "\"> names no texture of frame " + (frame->GetName() ? frame->GetName() : "(unnamed)"));
            }

            lua_settop(L, top);
        }

        s_pending.erase(s_pending.begin() + i);
    }
}

// ModernUI_AddMaskTexture(texture, mask) / ModernUI_RemoveMaskTexture(texture, mask)
int32_t Script_ModernUI_AddMaskTexture(lua_State* L) {
    ModernUI_AddMask(TextureFromLua(L, 1), TextureFromLua(L, 2));
    return 0;
}

int32_t Script_ModernUI_RemoveMaskTexture(lua_State* L) {
    ModernUI_RemoveMask(TextureFromLua(L, 1), TextureFromLua(L, 2));
    return 0;
}
