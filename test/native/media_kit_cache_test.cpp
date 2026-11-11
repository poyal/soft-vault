#include "../../windows/runner/media_kit_cache.h"
#include <fstream>
#include <filesystem>
#include <iostream>

int main() {
  wchar_t temp[32768];
  if (!GetTempPathW(32768, temp)) return 1;
  const auto directory = std::filesystem::path(temp) /
      (L"soft-vault-cache-test-" + std::to_wstring(GetCurrentProcessId()));
  std::filesystem::create_directory(directory);
  const auto current = directory /
      L"com.alexmercerind.media_kit.NativeReferenceHolder.123";
  const auto other = directory /
      L"com.alexmercerind.media_kit.NativeReferenceHolder.456";
  std::ofstream(current) << "2049621451536";
  std::ofstream(other) << "keep";
  if (!ClearMediaKitProcessCache(directory.wstring(), 123) ||
      std::filesystem::exists(current) || !std::filesystem::exists(other)) return 2;
  if (!ClearMediaKitProcessCache(directory.wstring(), 123)) return 3;
  HANDLE locked = CreateFileW(current.c_str(), GENERIC_WRITE, 0, nullptr,
                              CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (locked == INVALID_HANDLE_VALUE) return 4;
  const bool rejected = !ClearMediaKitProcessCache(directory.wstring(), 123);
  CloseHandle(locked);
  if (!rejected) return 5;
  if (!ClearMediaKitProcessCache(directory.wstring(), 123)) return 6;
  std::filesystem::remove(other);
  std::filesystem::remove(directory);
  std::cout << "stale address, other PID, missing cache and locked cache: passed\n";
  return 0;
}
