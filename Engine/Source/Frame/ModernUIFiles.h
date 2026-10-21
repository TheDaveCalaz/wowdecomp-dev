#ifndef ENGINE_FRAME_MODERNUIFILES_H
#define ENGINE_FRAME_MODERNUIFILES_H

#include <cstddef>
#include <cstdint>

// Not in the original client: texture files named the modern way.
//
// Modern clients name files by number (file data ID). ModernUI_FileIDs.txt, next to the executable, maps the
// interface textures' numbers to their paths ("130716;buttons/button-backpack-up"); a number given as a texture
// becomes "Interface\buttons\button-backpack-up". Textures this client's own files lack can be exported from a
// modern client into Interface\ModernArt\ (keeping their folders); a path that does not load is tried there.

// A texture name that is a file number, as a path. Returns false for anything else.
bool ModernUI_ResolveFileID(const char* name, char* out, size_t size);
// The file's path under Interface\ModernArt\, or false when the name is already there or is empty.
bool ModernUI_ModernArtPath(const char* name, char* out, size_t size);
// The path for a file number, or null.
const char* ModernUI_PathForFileID(uint32_t id);
// The file number for a path, or 0.
uint32_t ModernUI_FileIDForPath(const char* path);

#endif
