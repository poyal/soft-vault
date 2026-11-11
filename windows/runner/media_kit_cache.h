#ifndef RUNNER_MEDIA_KIT_CACHE_H_
#define RUNNER_MEDIA_KIT_CACHE_H_

#include <windows.h>
#include <string>

// media_kit 1.2.6's debug hot-restart cache contains a raw process address.
// A new process can reuse an old PID, but must never reuse that address.
// Call once from wWinMain, before starting Dart; hot restart does not enter here.
inline bool ClearMediaKitProcessCache(const std::wstring& directory,
                                     DWORD process_id) {
  const auto file = directory + L"\\com.alexmercerind.media_kit.NativeReferenceHolder." +
                    std::to_wstring(process_id);
  if (::DeleteFileW(file.c_str())) return true;
  const auto error = ::GetLastError();
  return error == ERROR_FILE_NOT_FOUND || error == ERROR_PATH_NOT_FOUND;
}

inline bool PrepareMediaKitDebugCache() {
#ifndef NDEBUG
  wchar_t directory[32768];
  const auto length = ::GetTempPathW(32768, directory);
  if (length == 0 || length >= 32768) return false;
  return ClearMediaKitProcessCache(directory, ::GetCurrentProcessId());
#else
  return true;
#endif
}

#endif  // RUNNER_MEDIA_KIT_CACHE_H_
