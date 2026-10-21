#include "Engine/Source/Frame/ModernUIFiles.h"
#include <cctype>
#include <cstdio>
#include <cstring>
#include <string>
#include <unordered_map>

namespace {

struct FileTable {
    bool loaded = false;
    std::unordered_map<uint32_t, std::string> paths;   // id -> "Interface\buttons\button-backpack-up"
    std::unordered_map<std::string, uint32_t> ids;     // lower-case path with '\' and no extension -> id
};

std::string Normalise(const char* path) {
    std::string key;

    for (const char* p = path; *p; p++) {
        char c = *p == '/' ? '\\' : static_cast<char>(tolower(static_cast<unsigned char>(*p)));
        key += c;
    }

    size_t dot = key.rfind('.');

    if (dot != std::string::npos && key.find('\\', dot) == std::string::npos) {
        key.erase(dot);
    }

    return key;
}

FileTable& Table() {
    static FileTable table;

    if (table.loaded) {
        return table;
    }

    table.loaded = true;
    FILE* file = fopen("ModernUI_FileIDs.txt", "rb");

    if (!file) {
        return table;
    }

    char line[512];

    while (fgets(line, sizeof(line), file)) {
        char* separator = strchr(line, ';');

        if (!separator) {
            continue;
        }

        *separator = '\0';
        char* path = separator + 1;
        size_t length = strlen(path);

        while (length && (path[length - 1] == '\n' || path[length - 1] == '\r')) {
            path[--length] = '\0';
        }

        uint32_t id = static_cast<uint32_t>(strtoul(line, nullptr, 10));
        std::string full = "Interface\\";

        for (const char* p = path; *p; p++) {
            full += *p == '/' ? '\\' : *p;
        }

        table.ids.emplace(Normalise(full.c_str()), id);
        table.paths.emplace(id, std::move(full));
    }

    fclose(file);
    return table;
}

}

const char* ModernUI_PathForFileID(uint32_t id) {
    FileTable& table = Table();
    auto it = table.paths.find(id);
    return it == table.paths.end() ? nullptr : it->second.c_str();
}

uint32_t ModernUI_FileIDForPath(const char* path) {
    if (!path || !*path) {
        return 0;
    }

    FileTable& table = Table();
    auto it = table.ids.find(Normalise(path));
    return it == table.ids.end() ? 0 : it->second;
}

bool ModernUI_ResolveFileID(const char* name, char* out, size_t size) {
    if (!name || !*name) {
        return false;
    }

    for (const char* p = name; *p; p++) {
        if (*p < '0' || *p > '9') {
            return false;
        }
    }

    const char* path = ModernUI_PathForFileID(static_cast<uint32_t>(strtoul(name, nullptr, 10)));

    if (!path) {
        return false;
    }

    snprintf(out, size, "%s", path);
    return true;
}

bool ModernUI_ModernArtPath(const char* name, char* out, size_t size) {
    if (!name || !*name) {
        return false;
    }

    std::string key = Normalise(name);

    if (key.compare(0, 19, "interface\\modernart") == 0) {
        return false;
    }

    // Exported art keeps the folders below Interface: Interface\ModernArt\buttons\..., Interface\ModernArt\icons\...
    std::string path = key.compare(0, 10, "interface\\") == 0 ? std::string(name + 10) : std::string(name);

    for (char& c : path) {
        if (c == '/') {
            c = '\\';
        }
    }

    snprintf(out, size, "Interface\\ModernArt\\%s", path.c_str());
    return true;
}
