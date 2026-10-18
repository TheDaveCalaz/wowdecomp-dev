// Not in the original client: see ModernUI.h.

#include "ModernUI.h"
#include "Engine/Source/Base/Status.h"
#include "Engine/Source/FrameScript/FrameScript.h"
#include "Engine/Source/FrameXML/FrameXML.h"
#include "Engine/Source/Storm/H/storm.h"
#include "Engine/Source/Storm/Source/MD5.h"
#include "ModernUI_Embedded.h"

static bool IsXML(const char* name) {
    size_t length = SStrLen(name);
    return length > 4 && !SStrCmpI(name + length - 4, ".xml", 4);
}

void ModernUI_Load(CStatus* status) {
    // Lua first, in file-name order...
    for (const ModernUIFile* file = s_modernUIFiles; file->name; ++file) {
        if (!IsXML(file->name)) {
            FrameScript_Execute(file->source, file->name, nullptr);
        }
    }

    // ...then the XML templates, which may use what the Lua defined.
    for (const ModernUIFile* file = s_modernUIFiles; file->name; ++file) {
        if (IsXML(file->name)) {
            MD5_CTX md5;
            MD5Init(&md5);
            FrameXML_RegisterBuiltInFile(file->name, file->source, file->size);
            FrameXML_ProcessFile(file->name, nullptr, &md5, status);
        }
    }
}
