#pragma once

// Not in the original client: PNG and JPEG texture loading. See TextureImage.cpp.

#include "Engine/Source/Gx/CGxTexFlags.h"

class CTexture;

CTexture* CreateImageTexture(const char* fileName, CGxTexFlags texFlags);
