#pragma once

// Not in the original client.
// Runs the built-in modern addon layer (C_ namespaces, Enum, Mixin, pools, CallbackRegistry...)
// after FrameXML has loaded and before any addon, so modern addons find it as on a modern client.
class CStatus;

void ModernUI_Load(CStatus* status);
