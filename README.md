# ScreenMac

**A native macOS screenshot app for capturing a screen region, adding annotations, and copying or saving the result.** Built with Swift, SwiftUI, AppKit, and ScreenCaptureKit.

![ScreenMac app icon](ScreenMac/Resources/ScreenMacIcon.svg)

ScreenMac runs in the menu bar and supports macOS 14 or later on Apple silicon and Intel Macs.

[Русская версия](#screenmac-на-русском)

## Features

- Capture a selected region on the display under the pointer.
- Start capture from the menu bar or with the configurable global shortcut (default: `⌥⌘2`).
- Annotate screenshots with arrows, rectangles, lines, freehand drawing, and text.
- Copy the finished image to the clipboard or save it as PNG.
- Optionally launch at login.

## Download

The 1.10 DMG supplied with the source archive has a valid disk image checksum. The app bundle in the accompanying Xcode archive does not pass Gatekeeper's trust assessment, and the DMG contents could not be inspected in this environment. Treat the DMG as unverified. A public installer should be rebuilt, signed with an Apple Developer ID certificate, and notarized before it is offered as a ready-to-install download. Until then, build ScreenMac from source using the instructions below.

## Build from source

1. Install Xcode 15 or later.
2. Open `ScreenMac.xcodeproj` and select the **ScreenMac** scheme and **My Mac** destination.
3. In **Signing & Capabilities**, choose your own development team for local signing.
4. Build and run with `⌘R`.
5. On the first capture, grant ScreenMac permission under **System Settings → Privacy & Security → Screen & System Audio Recording**, then quit and reopen the app if macOS asks.

The app uses bundle identifier `com.anatoliyzyk.ScreenMac`. After building it yourself, macOS treats it as a separate app and may request screen recording permission again.

## Use

ScreenMac stays in the menu bar and does not show in the Dock. Use the camera menu icon to open settings or start a capture. Drag to select a region; press `Esc` to cancel. In the editor, choose an annotation tool and use `⌘C` to copy the result. Saving a PNG is a separate action. Closing the editor discards that capture.

## Notes

- Capture runs on the display where the pointer is when capture starts. A selection cannot cross between displays.
- ScreenCaptureKit captures the selected display when you request a screenshot. macOS controls the screen recording permission.
- Login launch is off by default. For reliable login launch, keep the app in `/Applications`.

## License

The project license has not been selected yet. Until a license is added, the source is public for inspection, but reuse, modification, and redistribution are not granted.

---

## ScreenMac на русском

**Нативное приложение macOS для снимков экрана: выделение области, аннотации, копирование в буфер обмена и сохранение в PNG.** Написано на Swift с использованием SwiftUI, AppKit и ScreenCaptureKit.

Работает в строке меню на macOS 14 и новее, на Apple silicon и Intel.

### Возможности

- Захват области на дисплее, где находится указатель.
- Запуск из меню камеры или настраиваемым глобальным сочетанием клавиш (по умолчанию `⌥⌘2`).
- Аннотации: стрелки, прямоугольники, линии, карандаш и текст.
- Копирование результата в буфер обмена или сохранение в PNG.
- Необязательный запуск при входе в систему.

### Скачать или собрать

DMG версии 1.10 из исходного архива прошёл проверку контрольной суммы. Приложение из приложенного Xcode-архива не прошло проверку доверия Gatekeeper, а содержимое DMG в этой среде проверить не удалось, поэтому установщик считаем непроверенным. Перед публикацией готового установщика нужно пересобрать приложение, подписать сертификатом Apple Developer ID и нотариализовать. Пока этого нет, соберите приложение из исходников: откройте `ScreenMac.xcodeproj` в Xcode 15 или новее, выберите схему **ScreenMac** и устройство **My Mac**, укажите свою команду для локальной подписи и запустите через `⌘R`.

При первом снимке разрешите запись экрана в **Системные настройки → Конфиденциальность и безопасность → Запись экрана и системного аудио**. При необходимости завершите и снова запустите приложение. Идентификатор приложения — `com.anatoliyzyk.ScreenMac`.

Приложение остаётся в строке меню и не показывает значок в Dock. Закрытие редактора отменяет текущий снимок; для выхода используйте меню камеры. Захват выполняется на дисплее под указателем при запуске; область через границу двух дисплеев выбрать нельзя. Автозапуск выключен по умолчанию.

### Лицензия

Лицензия проекта ещё не выбрана. Пока она не добавлена, исходный код доступен для просмотра, но право на его повторное использование, изменение и распространение не предоставляется.
