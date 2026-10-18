// Not in the original client: see ModernUI.h.

#include "ModernUI.h"
#include "Engine/Source/FrameScript/FrameScript.h"
#include "ModernUI_Embedded.h"

void ModernUI_Load() {
    for (const ModernUIFile* file = s_modernUIFiles; file->name; ++file) {
        FrameScript_Execute(file->source, file->name, nullptr);
    }
}
