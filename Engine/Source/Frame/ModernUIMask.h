#pragma once

// Not in the original client: mask textures (Texture:AddMaskTexture, <MaskTexture> with <MaskedTextures>), as
// modern clients draw them. See ModernUIMask.cpp.

#include <cstdint>

class CSimpleTexture;
class CSimpleFrame;
class CTexture;
class XMLNode;
struct lua_State;

void ModernUI_AddMask(CSimpleTexture* texture, CSimpleTexture* mask);
void ModernUI_RemoveMask(CSimpleTexture* texture, CSimpleTexture* mask);
void ModernUI_ForgetMaskTexture(CSimpleTexture* texture); // a texture going away
bool ModernUI_HasMasks(const CSimpleTexture* texture);

// The texture to draw in place of a masked one, with texture coordinates covering it whole; nullptr when the
// texture has no masks or the composition cannot be made (it is then drawn unmasked).
CTexture* ModernUI_MaskedTexture(CSimpleTexture* texture);

// XML: a <MaskTexture> naming the textures it masks (<MaskedTextures><MaskedTexture childKey="Icon"/>); the keys
// are resolved once the frame has loaded (ModernUI_ResolveXMLMasks from CSimpleFrame::PostLoadXML).
void ModernUI_NoteXMLMask(CSimpleFrame* frame, CSimpleTexture* mask, XMLNode* node);
void ModernUI_ResolveXMLMasks(CSimpleFrame* frame);

int32_t Script_ModernUI_AddMaskTexture(lua_State* L);
int32_t Script_ModernUI_RemoveMaskTexture(lua_State* L);
