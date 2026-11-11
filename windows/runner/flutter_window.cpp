#include "flutter_window.h"

#include <optional>
#include <shobjidl.h>
#include <shlobj.h>
#include <shellapi.h>
#include <filesystem>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  window_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "soft_vault/window",
      &flutter::StandardMethodCodec::GetInstance());
  window_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        if (call.method_name() == "minimize") {
          // window_manager deliberately ignores minimization in fullscreen.
          // Panic must work there too, while retaining fullscreen placement.
          ShowWindow(GetHandle(), SW_MINIMIZE);
          result->Success();
        } else if (call.method_name() == "trash" || call.method_name() == "reveal") {
          const auto* path = std::get_if<std::string>(call.arguments());
          if (!path) { result->Error("argument", "Missing file path"); return; }
          const auto wide = std::filesystem::absolute(std::filesystem::u8path(*path)).make_preferred().wstring();
          IShellItem* item = nullptr;
          HRESULT hr = SHCreateItemFromParsingName(wide.c_str(), nullptr, IID_PPV_ARGS(&item));
          if (SUCCEEDED(hr) && call.method_name() == "reveal") {
            PIDLIST_ABSOLUTE pidl = nullptr;
            hr = SHGetIDListFromObject(item, &pidl);
            if (SUCCEEDED(hr)) { hr = SHOpenFolderAndSelectItems(pidl, 0, nullptr, 0); CoTaskMemFree(pidl); }
          } else if (SUCCEEDED(hr)) {
            IFileOperation* operation = nullptr;
            hr = CoCreateInstance(CLSID_FileOperation, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&operation));
            if (SUCCEEDED(hr)) {
              // Refuse permanent deletion when recycling is unavailable.
              hr = operation->SetOperationFlags(FOF_ALLOWUNDO | FOF_NOCONFIRMATION | FOF_NOERRORUI | FOF_SILENT | FOFX_RECYCLEONDELETE | FOFX_EARLYFAILURE);
              if (SUCCEEDED(hr)) hr = operation->DeleteItem(item, nullptr);
              if (SUCCEEDED(hr)) hr = operation->PerformOperations();
              BOOL aborted = FALSE;
              operation->GetAnyOperationsAborted(&aborted);
              if (aborted) hr = E_ABORT;
              operation->Release();
            }
          }
          if (item) item->Release();
          if (FAILED(hr)) result->Error("file_operation", "File operation failed", flutter::EncodableValue(static_cast<int>(hr)));
          else result->Success();
        } else {
          result->NotImplemented();
        }
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  window_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
