// Not in the original client: CopyToClipboard(text) for the modern addon layer (modern clients have it).
// Kept in its own file so <windows.h> stays out of the UI sources.

#include <cstring>

#if defined(_WIN32)
#include <windows.h>
#endif

bool ModernUI_CopyToClipboard(const char* text) {
#if defined(_WIN32)
    if (!text) {
        return false;
    }

    int wideLength = MultiByteToWideChar(CP_UTF8, 0, text, -1, nullptr, 0);

    if (wideLength <= 0 || !OpenClipboard(nullptr)) {
        return false;
    }

    EmptyClipboard();
    HGLOBAL memory = GlobalAlloc(GMEM_MOVEABLE, static_cast<SIZE_T>(wideLength) * sizeof(wchar_t));
    bool copied = false;

    if (memory) {
        wchar_t* buffer = static_cast<wchar_t*>(GlobalLock(memory));

        if (buffer) {
            MultiByteToWideChar(CP_UTF8, 0, text, -1, buffer, wideLength);
            GlobalUnlock(memory);
            copied = SetClipboardData(CF_UNICODETEXT, memory) != nullptr;
        }

        if (!copied) {
            GlobalFree(memory);
        }
    }

    CloseClipboard();
    return copied;
#else
    (void)text;
    return false;
#endif
}
