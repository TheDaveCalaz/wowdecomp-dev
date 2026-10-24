// Not in the original client: PNG and JPEG textures, as modern clients load them.
//
// When a texture is not found as .blp or .tga, TextureCreate asks here. The file is looked for as named,
// then with .png, .jpg and .jpeg added, decoded with stb_image, and handed to the graphics device in the same
// 32-bit format the TGA loader uses, with a mip chain built by averaging.

#include "Engine/Source/Services/TextureImage.h"
#include <cstdint>
#include <cstring>
#include <vector>
#include "Engine/Source/BlizzardCore/SFile2-Core.h"
#include "Engine/Source/Base/Handle.h"
#include "Engine/Source/Services/Texture.h"
#include "Engine/Source/Storm/H/storm.h"
#include "Engine/Source/BLPFile/blp.h"

#define STB_IMAGE_IMPLEMENTATION
#define STBI_ONLY_PNG
#define STBI_ONLY_JPEG
#define STBI_ONLY_TGA
#define STBI_NO_STDIO
#include "ThirdParty/stb/stb_image.h"

namespace {

struct Mip {
    uint32_t width;
    uint32_t height;
    std::vector<uint8_t> texels; // B, G, R, A
};

std::vector<Mip> s_mips;

bool HasExtension(const char* fileName, const char* extension) {
    size_t length = SStrLen(fileName);
    size_t extLength = SStrLen(extension);
    return length > extLength && !SStrCmpI(fileName + length - extLength, extension, extLength);
}

// Reads and decodes a file into BGRA. Returns false if the file is missing or not a PNG/JPEG.
bool Decode(const char* path, Mip& out) {
    void* data = nullptr;
    uint32_t size = 0;

    if (!SFile::ReadFile(nullptr, path, &data, &size, 0, 1, nullptr)) {
        return false;
    }

    int32_t width = 0;
    int32_t height = 0;
    int32_t channels = 0;
    stbi_uc* pixels = stbi_load_from_memory(static_cast<const stbi_uc*>(data), static_cast<int32_t>(size), &width, &height, &channels, 4);
    SFile::Unload(data);

    if (!pixels) {
        return false;
    }

    out.width = static_cast<uint32_t>(width);
    out.height = static_cast<uint32_t>(height);
    out.texels.resize(static_cast<size_t>(width) * height * 4);

    for (size_t i = 0, n = static_cast<size_t>(width) * height; i < n; i++) {
        out.texels[i * 4 + 0] = pixels[i * 4 + 2];
        out.texels[i * 4 + 1] = pixels[i * 4 + 1];
        out.texels[i * 4 + 2] = pixels[i * 4 + 0];
        out.texels[i * 4 + 3] = pixels[i * 4 + 3];
    }

    stbi_image_free(pixels);
    return true;
}

// Finds the file: as named first, then with each image extension added.
bool Resolve(const char* fileName, char* path, size_t pathSize) {
    static const char* const s_extensions[] = { "", ".png", ".jpg", ".jpeg" };

    for (const char* extension : s_extensions) {
        if (*extension == '\0' && !HasExtension(fileName, ".png") && !HasExtension(fileName, ".jpg") && !HasExtension(fileName, ".jpeg")) {
            continue;
        }

        SStrPrintf(path, pathSize, "%s%s", fileName, extension);

        if (SFile::FileExistsEx(path, 1)) {
            return true;
        }
    }

    return false;
}

void BuildMips(const Mip& base) {
    s_mips.clear();
    s_mips.push_back(base);

    while (s_mips.back().width > 1 || s_mips.back().height > 1) {
        const Mip& src = s_mips.back();
        Mip dst;
        dst.width = src.width > 1 ? src.width / 2 : 1;
        dst.height = src.height > 1 ? src.height / 2 : 1;
        dst.texels.resize(static_cast<size_t>(dst.width) * dst.height * 4);

        for (uint32_t y = 0; y < dst.height; y++) {
            for (uint32_t x = 0; x < dst.width; x++) {
                uint32_t x0 = x * 2 < src.width ? x * 2 : src.width - 1;
                uint32_t x1 = x * 2 + 1 < src.width ? x * 2 + 1 : x0;
                uint32_t y0 = y * 2 < src.height ? y * 2 : src.height - 1;
                uint32_t y1 = y * 2 + 1 < src.height ? y * 2 + 1 : y0;

                for (uint32_t c = 0; c < 4; c++) {
                    uint32_t sum = src.texels[(y0 * src.width + x0) * 4 + c] + src.texels[(y0 * src.width + x1) * 4 + c]
                        + src.texels[(y1 * src.width + x0) * 4 + c] + src.texels[(y1 * src.width + x1) * 4 + c];
                    dst.texels[(y * dst.width + x) * 4 + c] = static_cast<uint8_t>((sum + 2) / 4);
                }
            }
        }

        s_mips.push_back(std::move(dst));
    }
}

void UpdateImageTexture(EGxTexCommand command, uint32_t width, uint32_t height, uint32_t face, uint32_t level, void* userArg, uint32_t& texelStrideInBytes, const void*& texels) {
    CTexture* texture = static_cast<CTexture*>(userArg);

    switch (command) {
        case GxTex_Lock: {
            Mip base;

            if (Decode(texture->m_filename, base)) {
                BuildMips(base);
            } else {
                // The file went away: fall back to a single white texel per level.
                s_mips.clear();
                Mip blank;
                blank.width = 1;
                blank.height = 1;
                blank.texels.assign(4, 0xFF);
                s_mips.push_back(blank);
            }

            break;
        }

        case GxTex_Latch: {
            size_t index = level < s_mips.size() ? level : s_mips.size() - 1;
            const Mip& mip = s_mips[index];

            // A level the device asks for in a size the chain does not have gets the nearest level.
            texelStrideInBytes = 4 * mip.width;
            texels = mip.texels.data();
            break;
        }

        default:
            break;
    }
}

} // namespace

CTexture* CreateImageTexture(const char* fileName, CGxTexFlags texFlags) {
    char path[260];

    if (!fileName || !Resolve(fileName, path, sizeof(path))) {
        return nullptr;
    }

    Mip base;

    if (!Decode(path, base) || base.width == 0 || base.height == 0) {
        return nullptr;
    }

    CTexture* texture = new ("HTEXTURE", SLOG_OBJECT) CTexture;

    if (!texture) {
        return nullptr;
    }

    bool hasAlpha = false;

    for (size_t i = 3; i < base.texels.size(); i += 4) {
        if (base.texels[i] != 0xFF) {
            hasAlpha = true;
            break;
        }
    }

    texture->m_alphaBits = hasAlpha ? 8 : 0;

    if (!hasAlpha) {
        texture->m_flags |= 1;
    }

    SStrCopy(texture->m_filename, path, sizeof(texture->m_filename));
    texture->m_gxTex = TextureAllocGxTex(GxTex_2d, base.width, base.height, 0, GxTex_Argb8888, texFlags, texture, UpdateImageTexture, GxTex_Argb8888, texture->m_filename);

    if (!texture->m_gxTex) {
        texture->~CTexture();
        SMemFree(texture, __FILE__, __LINE__, 0);
        return nullptr;
    }

    texture->m_gxTexTarget = GxTex_2d;
    texture->m_gxWidth = static_cast<uint16_t>(base.width);
    texture->m_gxHeight = static_cast<uint16_t>(base.height);

    return reinterpret_cast<CTexture*>(HandleCreate(texture, "HTEXTURE"));
}

// Decodes any texture file the client can show (BLP, TGA, PNG, JPEG) into BGRA texels, for code that needs the
// pixels themselves (the mask composition in Frame/ModernUIMask.cpp). The name may come with or without an
// extension, as texture names do.
bool ModernUI_DecodeTextureFile(const char* fileName, uint32_t& width, uint32_t& height, std::vector<uint8_t>& bgra) {
    if (!fileName || !*fileName) {
        return false;
    }

    char base[260];
    SStrCopy(base, fileName, sizeof(base));

    for (char* c = base; *c; c++) {
        if (*c == '/') {
            *c = '\\';
        }
    }

    char* dot = SStrChrR(base, '.');
    char* slash = SStrChrR(base, '\\');

    if (dot && (!slash || dot > slash)) {
        if (!SStrCmpI(dot, ".blp", STORM_MAX_STR) || !SStrCmpI(dot, ".tga", STORM_MAX_STR)) {
            *dot = '\0';
        }
    }

    // BLP
    char path[270];
    SStrPrintf(path, sizeof(path), "%s.blp", base);

    if (SFile::FileExistsEx(path, 1)) {
        CBLPFile image;

        if (image.Open(path, 0)) {
            uint8_t* data = nullptr;
            uint32_t stride = 0;

            if (image.Lock(PIXEL_ARGB8888, 0, data, stride) && data) {
                width = image.m_header.m_width;
                height = image.m_header.m_height;
                bgra.resize(static_cast<size_t>(width) * height * 4);

                for (uint32_t y = 0; y < height; y++) {
                    memcpy(&bgra[static_cast<size_t>(y) * width * 4], data + static_cast<size_t>(y) * stride, static_cast<size_t>(width) * 4);
                }

                image.Unlock(0);
                image.Close();
                return width && height;
            }

            image.Close();
        }
    }

    // TGA, PNG, JPEG
    static const char* const s_extensions[] = { ".tga", "", ".png", ".jpg", ".jpeg" };

    for (const char* extension : s_extensions) {
        SStrPrintf(path, sizeof(path), "%s%s", base, extension);

        if (!*extension && SStrCmpI(path, fileName, STORM_MAX_STR)) {
            SStrCopy(path, fileName, sizeof(path));
        }

        if (!SFile::FileExistsEx(path, 1)) {
            continue;
        }

        void* data = nullptr;
        uint32_t size = 0;

        if (!SFile::ReadFile(nullptr, path, &data, &size, 0, 1, nullptr)) {
            continue;
        }

        int32_t w = 0;
        int32_t h = 0;
        int32_t channels = 0;
        stbi_uc* pixels = stbi_load_from_memory(static_cast<const stbi_uc*>(data), static_cast<int32_t>(size), &w, &h, &channels, 4);
        SFile::Unload(data);

        if (!pixels) {
            continue;
        }

        width = static_cast<uint32_t>(w);
        height = static_cast<uint32_t>(h);
        bgra.resize(static_cast<size_t>(w) * h * 4);

        for (size_t i = 0, n = static_cast<size_t>(w) * h; i < n; i++) {
            bgra[i * 4 + 0] = pixels[i * 4 + 2];
            bgra[i * 4 + 1] = pixels[i * 4 + 1];
            bgra[i * 4 + 2] = pixels[i * 4 + 0];
            bgra[i * 4 + 3] = pixels[i * 4 + 3];
        }

        stbi_image_free(pixels);
        return width && height;
    }

    return false;
}
