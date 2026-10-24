#pragma once

// Not in the original client: PNG and JPEG texture loading. See TextureImage.cpp.

#include "Engine/Source/Gx/CGxTexFlags.h"
#include <cstdint>
#include <vector>

class CTexture;

CTexture* CreateImageTexture(const char* fileName, CGxTexFlags texFlags);

// Any texture file (BLP, TGA, PNG, JPEG) decoded into BGRA texels; false when it cannot be read.
bool ModernUI_DecodeTextureFile(const char* fileName, uint32_t& width, uint32_t& height, std::vector<uint8_t>& bgra);
