// Test process only. Sample the barcode only when our entire strip is visible.
#include <algorithm>
#include <cstdint>
#include <windows.h>

#define EXPORT extern "C" __declspec(dllexport)
static HWND trial_window;
static HANDLE thread;

struct WindowArgs {
  int width, height;
  HANDLE ready;
};
static DWORD WINAPI Pump(void *pointer) {
  const auto args = *static_cast<WindowArgs *>(pointer);
  WNDCLASSW wc{};
  wc.lpfnWndProc = DefWindowProcW;
  wc.hInstance = GetModuleHandleW(nullptr);
  wc.lpszClassName = L"SoftVaultFrameTrial";
  RegisterClassW(&wc);
  RECT bounds{0, 0, args.width, args.height};
  AdjustWindowRect(&bounds, WS_OVERLAPPEDWINDOW, FALSE);
  trial_window = CreateWindowW(wc.lpszClassName, L"Soft Vault playback test",
                               WS_VISIBLE | WS_OVERLAPPEDWINDOW, CW_USEDEFAULT,
                               CW_USEDEFAULT, bounds.right - bounds.left,
                               bounds.bottom - bounds.top, nullptr, nullptr,
                               wc.hInstance, nullptr);
  if (trial_window)
    SetForegroundWindow(trial_window);
  SetEvent(args.ready);
  MSG message{};
  while (GetMessageW(&message, nullptr, 0, 0) > 0) {
    TranslateMessage(&message);
    DispatchMessageW(&message);
  }
  DestroyWindow(trial_window);
  return 0;
}

EXPORT intptr_t trial_window_open(int width, int height) {
  WindowArgs args{width, height, CreateEventW(nullptr, FALSE, FALSE, nullptr)};
  thread = CreateThread(nullptr, 0, Pump, &args, 0, nullptr);
  if (thread)
    WaitForSingleObject(args.ready, INFINITE);
  CloseHandle(args.ready);
  return reinterpret_cast<intptr_t>(trial_window);
}

EXPORT int trial_window_frame() {
  RECT rect{};
  if (!trial_window || !GetClientRect(trial_window, &rect))
    return -1;
  const int h = rect.bottom, w = std::min<int>(rect.right, h * 16 / 9);
  if (w < 64)
    return -1;
  POINT left{(rect.right - w) / 2, h / 2};
  ClientToScreen(trial_window, &left);
  // Check ownership before requesting screen pixels. Read one row in one GPU
  // transfer rather than synchronizing the screen DC 16 times per sample.
  for (int i = 0; i < 16; i++) {
    POINT pixel{left.x + (2 * i + 1) * w / 32, left.y};
    HWND owner = WindowFromPoint(pixel);
    if (owner != trial_window && !IsChild(trial_window, owner))
      return -1;
  }
  HDC desktop = GetDC(nullptr);
  HDC memory = CreateCompatibleDC(desktop);
  HBITMAP bitmap = CreateCompatibleBitmap(desktop, w, 1);
  HGDIOBJ prior = SelectObject(memory, bitmap);
  const BOOL copied =
      BitBlt(memory, 0, 0, w, 1, desktop, left.x, left.y, SRCCOPY);
  int value = copied ? 0 : -1;
  for (int i = 0; value >= 0 && i < 16; i++) {
    COLORREF color = GetPixel(memory, (2 * i + 1) * w / 32, 0);
    if (color == CLR_INVALID) {
      value = -1;
      break;
    }
    bool white = GetRValue(color) > 160;
    if ((i == 0 || i == 15) && !white) {
      value = -1;
      break;
    }
    if (i == 14 && white) {
      value = -1;
      break;
    }
    if (i > 0 && i < 14 && white)
      value |= 1 << (i - 1);
  }
  SelectObject(memory, prior);
  DeleteObject(bitmap);
  DeleteDC(memory);
  ReleaseDC(nullptr, desktop);
  return value;
}

EXPORT void trial_window_close() {
  if (thread) {
    PostThreadMessageW(GetThreadId(thread), WM_QUIT, 0, 0);
    WaitForSingleObject(thread, INFINITE);
    CloseHandle(thread);
    thread = nullptr;
    trial_window = nullptr;
  }
}
