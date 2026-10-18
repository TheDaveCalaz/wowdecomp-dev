// Not in the original client: see TextureFileIDs.h.

#include "Engine/Source/Services/TextureFileIDs.h"

const char* TextureFileIDToPath(uint32_t id) {
    uint32_t low = 0;
    uint32_t high = g_numTextureFileIDs;

    while (low < high) {
        uint32_t mid = low + (high - low) / 2;

        if (g_textureFileIDs[mid].id < id) {
            low = mid + 1;
        } else {
            high = mid;
        }
    }

    if (low < g_numTextureFileIDs && g_textureFileIDs[low].id == id) {
        return g_textureFileIDs[low].path;
    }

    return nullptr;
}

const char* TextureResolveFileID(const char* name) {
    if (!name || !*name) {
        return name;
    }

    uint32_t id = 0;

    for (const char* c = name; *c; ++c) {
        if (*c < '0' || *c > '9' || id > 100000000) {
            return name;
        }

        id = id * 10 + static_cast<uint32_t>(*c - '0');
    }

    const char* path = TextureFileIDToPath(id);
    return path ? path : name;
}
