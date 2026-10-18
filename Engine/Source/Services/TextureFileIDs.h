#pragma once

// Not in the original client: modern addons name textures by file ID (e.g. 133628) instead of by path.
// This table maps the IDs of the interface art that existed before file IDs did to their 3.3.5 paths.

#include <cstdint>

struct TextureFileID {
    uint32_t id;
    const char* path; // without the .blp extension
};

extern const TextureFileID g_textureFileIDs[];
extern const uint32_t g_numTextureFileIDs;

// Returns the path for a file ID, or nullptr if it is not known.
const char* TextureFileIDToPath(uint32_t id);

// If name is all digits and a known file ID, returns its path; otherwise returns name unchanged.
const char* TextureResolveFileID(const char* name);
