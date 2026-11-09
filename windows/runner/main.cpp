#include <windows.h>

#include <dwmapi.h>
#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter_windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);

  // Fixed-size overlay that starts near the bottom of the primary display.
  constexpr unsigned int kWindowWidth = 800;
  constexpr unsigned int kWindowHeight = 160;
  constexpr int kBottomMargin = 48;

  RECT work_area{};
  if (!::SystemParametersInfo(SPI_GETWORKAREA, 0, &work_area, 0)) {
    ::GetClientRect(::GetDesktopWindow(), &work_area);
  }

  HMONITOR monitor = ::MonitorFromPoint(POINT{0, 0}, MONITOR_DEFAULTTOPRIMARY);
  double scale = FlutterDesktopGetDpiForMonitor(monitor) / 96.0;
  if (scale <= 0.0) {
    scale = 1.0;
  }

  const int centered_x =
      work_area.left +
      (work_area.right - work_area.left -
       static_cast<int>(kWindowWidth * scale)) /
          2;
  const int bottom_y =
      work_area.bottom -
      static_cast<int>((kWindowHeight + kBottomMargin) * scale);

  Win32Window::Point origin(
      static_cast<unsigned int>(centered_x / scale),
      static_cast<unsigned int>(bottom_y / scale));
  Win32Window::Size size(kWindowWidth, kWindowHeight);
  if (!window.Create(L"poly_cript", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  // Extend the DWM frame across the whole client area so the Flutter surface
  // can use per-pixel alpha and show the desktop through transparent pixels.
  MARGINS margins = {-1, -1, -1, -1};
  ::DwmExtendFrameIntoClientArea(window.GetHandle(), &margins);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
