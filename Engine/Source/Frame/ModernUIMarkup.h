#ifndef ENGINE_FRAME_MODERNUIMARKUP_H
#define ENGINE_FRAME_MODERNUIMARKUP_H

// Not in the original client: text markup that modern clients understand and this one's font renderer
// does not. Atlas icons (|A:atlas:height:width[:x:y]|a) become texture markup (|T...|t) when the atlas is
// known and are dropped otherwise; named colours (|cnNAME:text|r) become |cffRRGGBB. Text without either
// is returned unchanged; converted text lives in a buffer that the next call reuses.

const char* ModernUI_ConvertMarkup(const char* text);
void ModernUI_RegisterAtlas(const char* name, const char* file, float width, float height, float left, float right, float top, float bottom);
// Looks up a registered atlas: its file, size in UI units and texture coordinates.
bool ModernUI_FindAtlas(const char* name, const char** file, float* width, float* height, float* left, float* right, float* top, float* bottom);
void ModernUI_RegisterColorName(const char* name, float r, float g, float b);

#endif
