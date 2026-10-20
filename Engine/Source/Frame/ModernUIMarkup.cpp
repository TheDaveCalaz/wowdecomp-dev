#include "Engine/Source/Frame/ModernUIMarkup.h"
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <unordered_map>

namespace {

struct AtlasEntry {
    std::string file;
    float width;
    float height;
    float left;
    float right;
    float top;
    float bottom;
};

std::unordered_map<std::string, AtlasEntry>& Atlases() {
    static std::unordered_map<std::string, AtlasEntry> atlases;
    return atlases;
}

std::unordered_map<std::string, std::string>& ColorNames() {
    static std::unordered_map<std::string, std::string> colors;
    return colors;
}

int ToByte(float value) {
    int byte = static_cast<int>(value * 255.0f + 0.5f);
    return byte < 0 ? 0 : (byte > 255 ? 255 : byte);
}

// Splits "a:b:c" into fields.
void SplitFields(const std::string& body, std::string* fields, int maxFields, int& count) {
    count = 0;
    size_t start = 0;

    while (count < maxFields) {
        size_t colon = body.find(':', start);
        fields[count++] = body.substr(start, colon == std::string::npos ? std::string::npos : colon - start);

        if (colon == std::string::npos) {
            break;
        }

        start = colon + 1;
    }
}

void AppendAtlas(std::string& out, const std::string& body) {
    std::string fields[8];
    int count = 0;
    SplitFields(body, fields, 8, count);

    auto it = Atlases().find(fields[0]);

    if (it == Atlases().end()) {
        return;
    }

    const AtlasEntry& atlas = it->second;
    int height = count > 1 ? atoi(fields[1].c_str()) : 0;
    int width = count > 2 ? atoi(fields[2].c_str()) : 0;
    int offsetX = count > 3 ? atoi(fields[3].c_str()) : 0;
    int offsetY = count > 4 ? atoi(fields[4].c_str()) : 0;

    if (height > 0 && width <= 0) {
        width = atlas.height > 0.0f ? static_cast<int>(height * atlas.width / atlas.height + 0.5f) : height;
    }

    // Texture coordinates go in as pixels of a notional 4096-pixel texture.
    char buffer[600];
    snprintf(buffer, sizeof(buffer), "|T%s:%d:%d:%d:%d:4096:4096:%d:%d:%d:%d|t", atlas.file.c_str(), height, width, offsetX, offsetY,
        static_cast<int>(atlas.left * 4096.0f + 0.5f), static_cast<int>(atlas.right * 4096.0f + 0.5f),
        static_cast<int>(atlas.top * 4096.0f + 0.5f), static_cast<int>(atlas.bottom * 4096.0f + 0.5f));
    out += buffer;
}

}

void ModernUI_RegisterAtlas(const char* name, const char* file, float width, float height, float left, float right, float top, float bottom) {
    if (!name || !file) {
        return;
    }

    Atlases()[name] = AtlasEntry { file, width, height, left, right, top, bottom };
}

bool ModernUI_FindAtlas(const char* name, const char** file, float* width, float* height, float* left, float* right, float* top, float* bottom) {
    if (!name) {
        return false;
    }

    auto it = Atlases().find(name);

    if (it == Atlases().end()) {
        return false;
    }

    const AtlasEntry& atlas = it->second;
    *file = atlas.file.c_str();
    *width = atlas.width;
    *height = atlas.height;
    *left = atlas.left;
    *right = atlas.right;
    *top = atlas.top;
    *bottom = atlas.bottom;
    return true;
}

void ModernUI_RegisterColorName(const char* name, float r, float g, float b) {
    if (!name) {
        return;
    }

    char hex[16];
    snprintf(hex, sizeof(hex), "|cff%02x%02x%02x", ToByte(r), ToByte(g), ToByte(b));
    ColorNames()[name] = hex;
}

const char* ModernUI_ConvertMarkup(const char* text) {
    if (!text || (!strstr(text, "|A:") && !strstr(text, "|cn"))) {
        return text;
    }

    static std::string out;
    out.clear();

    const char* p = text;

    while (*p) {
        if (p[0] == '|' && p[1] == '|') {
            out += "||";
            p += 2;
            continue;
        }

        if (p[0] == '|' && p[1] == 'A' && p[2] == ':') {
            const char* end = strstr(p + 3, "|a");

            if (end) {
                AppendAtlas(out, std::string(p + 3, end - (p + 3)));
                p = end + 2;
                continue;
            }
        }

        if (p[0] == '|' && p[1] == 'c' && p[2] == 'n') {
            const char* colon = strchr(p + 3, ':');

            if (colon && colon - (p + 3) < 64) {
                auto it = ColorNames().find(std::string(p + 3, colon - (p + 3)));
                out += it != ColorNames().end() ? it->second : std::string("|cffffffff");
                p = colon + 1;
                continue;
            }
        }

        out += *p++;
    }

    return out.c_str();
}
