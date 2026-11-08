# Промпт-план: собрать MultiClock Free на Маке

Всё, что ниже черты, вставьте в Claude Code, Codex или любого кодового агента
на Маке. Здесь цель, ограничения, приёмочные тесты и ловушки, в которые мы уже
попали, чтобы агент собрал всё с первого раза.

---

## Цель

Собрать **MultiClock Free**: крошечное приложение для строки меню macOS,
которое показывает два часовых пояса рядом с системными часами, например
`DE 23:57   MSK 01:57⁺¹`. Оно должно собраться, пройти проверки, установиться
и запуститься на этом Маке сегодня, имея только Command Line Tools от Apple.
Без Xcode.app, без Homebrew, без сторонних пакетов, без сети.

## Жёсткие ограничения

1. Язык и фреймворки: только Swift и AppKit. Сборка: SwiftPM, `Package.swift`
   (`swift-tools-version:5.9`, платформа `.macOS(.v10_15)`).
2. Работает на macOS 10.15 Catalina и новее, на Apple Silicon и Intel.
   Бинарник универсальный.
3. Без XCTest. В Command Line Tools его нет, `swift test` падает с
   `error: XCTest not available`. Тесты — исполняемый таргет
   `multiclock-check` со своим помощником-утверждением в три строки;
   `swift run multiclock-check` возвращает ненулевой код при любом провале.
4. Без иконки в Доке: `LSUIElement = true` и
   `NSApp.setActivationPolicy(.accessory)`.
5. Один экземпляр: если при запуске уже работает процесс с тем же
   идентификатором пакета, выйти.
6. Настройки в `UserDefaults` под ключами `zone1` и `zone2` в виде
   `ПОДПИСЬ|Region/City`. Битое или пустое значение заменяется значением по
   умолчанию.
7. Автозапуск через пользовательский LaunchAgent
   `~/Library/LaunchAgents/com.fedrbodr.multiclock.plist`, который приложение
   само пишет и удаляет по переключателю в меню. Без SMAppService, без
   вспомогательных инструментов, без вызовов `launchctl` (файл сработает при
   следующем входе, этого достаточно).
8. Всё, что можно проверить юнит-тестом, живёт в библиотеке
   `MultiClockCore`. Исполняемый таргет `MultiClock` — только склейка AppKit.

## Функции

- Элемент строки меню с текстом моноширинными цифрами
  (`NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)`),
  обновляется таймером раз в секунду с допуском 0.3, но заголовок
  переустанавливается только когда строка изменилась.
- Формат: `<подпись> <время>` на пояс, пояса через три пробела. Формат
  времени из локали пользователя по шаблону `jmm` (24 часа в de_DE,
  `11:57 PM` в en_US).
- Маркер дня: если календарная дата в поясе отличается от местной в тот же
  момент, добавить `⁺¹` или `⁻¹` (надстрочные символы Unicode).
- По умолчанию: пояс 1 `DE` = `Europe/Berlin`, пояс 2 `MSK` = `Europe/Moscow`.
- Пресеты (подпись ≤ 4 символов, все идентификаторы IANA валидны, без
  дублей): DE Berlin, MSK Moscow, UA Kyiv, UK London, PT Lisbon, RS Belgrade,
  TR Istanbul, GE Tbilisi, AM Yerevan, UAE Dubai, KZ Almaty, IN Kolkata, TH
  Bangkok, BALI Makassar, SG Singapore, JP Tokyo, SYD Sydney, NY New_York,
  LA Los_Angeles, UTC.
- Меню: две неактивные строки с полной датой
  (`MSK  Sun 9 Nov 01:57  ·  Europe/Moscow`), разделитель, подменю
  **Первый пояс** и **Второй пояс** (пресеты с галочкой на текущем,
  разделитель, **Другой…**), разделитель, переключатель **Запускать при
  входе** с галочкой, **Выход** (⌘Q). Подписи двуязычные:
  `Первый пояс / First zone`.
- **Другой…** открывает `NSAlert` с двумя полями: `NSTextField` для подписи
  и `NSComboBox` со списком `TimeZone.knownTimeZoneIdentifiers`,
  `completes = true`. Неизвестный идентификатор → предупреждение, ничего не
  сохраняется. Пустая подпись → подпись по умолчанию: до 4 заглавных букв
  города (`Europe/Lisbon` → `LISB`, `America/New_York` → `NEWY`,
  `UTC` → `UTC`).

## Структура репозитория

```
Package.swift
Sources/MultiClockCore/Zone.swift          Zone, Presets
Sources/MultiClockCore/ClockRenderer.swift title(), segment(), dayOffset(), dayMarker(), detailLine()
Sources/MultiClockCore/LaunchAgent.swift   plist, install(), uninstall(), toggle(), isInstalled
Sources/MultiClock/main.swift              App: NSApplicationDelegate
Sources/multiclock-check/main.swift        проверки
Resources/Info.plist
build.sh
README.md  PROMPT.md  PROMPT.ru.md  LICENSE (MIT)  .gitignore (.build/ .swiftpm/ *.zip)
docs/native-clock.md  docs/images/before.png  docs/images/after.png
```

`ClockRenderer(locale:localZone:separator:)` принимает зависимости снаружи,
чтобы проверки были детерминированными: в тестах `Locale(identifier:
"de_DE")`, местный пояс `Europe/Berlin` и фиксированные
`Date(timeIntervalSince1970:)`.

## Приёмочные проверки (`swift run -c release multiclock-check`)

Фиксированные моменты: `late = 1_793_573_820` (2026-11-08 22:57 UTC = 23:57
Берлин, 01:57 следующего дня Москва), `noon = 1_782_900_000` (2026-07-01
10:00 UTC = 12:00 Берлин, 13:00 Москва, 19:00 Токио).

1. `Zone(label:"MSK", id:"Europe/Moscow").stored == "MSK|Europe/Moscow"` и
   разбирается обратно в равное значение.
2. `Zone(stored:)` даёт nil для `""`, `"no-separator"`, `"|Europe/Berlin"`,
   `"X|Mars/Olympus_Mons"`; обрезает пробелы в `" DE | Europe/Berlin "`.
3. `Zone.defaultLabel(for:)`: `Europe/Lisbon → LISB`, `America/New_York →
   NEWY`, `UTC → UTC`.
4. Каждый пресет принимается `TimeZone(identifier:)`; подписи ≤ 4 символов;
   подписи уникальны; идентификаторы уникальны; первый Берлин, второй Москва.
5. `title([DE Berlin, MSK Moscow], at: late) == "DE 23:57   MSK 01:57⁺¹"`.
6. `segment(MSK, at: noon) == "MSK 13:00"`, `dayOffset(Moscow, noon) == 0`.
7. `dayOffset(Moscow, late) == 1`; `dayOffset(Los_Angeles, late) == 0`;
   в `late + 3780 с` (01:00 Берлин) `dayOffset(Los_Angeles) == -1` и
   `dayMarker == "⁻¹"`.
8. С `en_US` сегмент Берлина в `late` начинается с `DE 11:57` и содержит `pm`
   без учёта регистра.
9. `detailLine(JP Tokyo, at: noon)` начинается с `JP  `, заканчивается на
   `Asia/Tokyo`, содержит `19:00`.
10. Заголовок одинаков в `noon` и `noon + 59 с`, отличается в `noon + 60 с`.
11. `LaunchAgent` во временной папке: в plist есть `Label`,
    `ProgramArguments == [executablePath]`, `RunAtLoad == true`,
    `KeepAlive == false`; имя файла `<label>.plist`; `toggle()` ставит,
    записанный файл читается обратно с той же меткой, повторный `toggle()`
    убирает, `uninstall()` идемпотентен.

Ожидаемый вывод: `multiclock-check: N checks passed, 0 failed`, код выхода 0.

## Ручные проверки (сделать, а не предположить)

1. `./build.sh` печатает путь установки, а `file` показывает
   `Mach-O universal binary with 2 architectures`.
2. `pgrep -x MultiClock` после повторного запуска показывает ровно один
   процесс.
3. `screencapture -x -R <x>,0,1000,30 out.png` строки меню показывает
   `DE HH:MM   MSK HH:MM` (сверить с `TZ=Europe/Berlin date +%H:%M`).
4. Клик по элементу: оба подменю открываются, выбор пресета сразу меняет
   заголовок, `defaults read com.fedrbodr.multiclock` показывает выбор.
5. **Запускать при входе** создаёт и удаляет plist; `plutil -lint` проходит.

## Контракт скрипта сборки (`build.sh`)

- Собирает release на каждую архитектуру: `swift build -c release --triple
  arm64-apple-macosx10.15 --product MultiClock` и то же с `x86_64`, затем
  `lipo -create` в `MultiClock.app/Contents/MacOS/MultiClock`.
  **Не** использовать `--arch arm64 --arch x86_64`: этот путь требует xcbuild
  из Xcode.app и падает на Command Line Tools.
- Копирует `Resources/Info.plist`, подписывает `codesign --force --sign -`
  (ad hoc), убивает запущенный экземпляр, открывает новый. Путь
  `~/Applications/MultiClock.app`, переопределяется через `APP=`.

## Ключи Info.plist

`CFBundleIdentifier com.fedrbodr.multiclock`, `CFBundleExecutable MultiClock`,
`CFBundleName MultiClock`, `CFBundleDisplayName MultiClock Free`,
`CFBundlePackageType APPL`, `CFBundleShortVersionString 1.0.0`,
`LSMinimumSystemVersion 10.15`, `LSUIElement true`, `NSHighResolutionCapable true`.

## Ловушки, в которые мы уже попали

- В Command Line Tools нет XCTest и xcbuild. См. ограничение 3 и контракт
  скрипта сборки.
- Если песочница агента не даёт писать в `~/Library/LaunchAgents`, не
  воевать: файл пишет само приложение по клику пользователя.
- Смена идентификатора пакета заставляет macOS забыть позицию элемента в
  строке меню. Сказать пользователю один раз перетащить его с ⌘.
- Системные часы из строки меню убрать нельзя. Их можно сжать до аналогового
  кружка без даты и дня недели, рецепт в `docs/native-clock.md`.
- Правее Пункта управления и системных часов элементы не ставятся; ближайшее
  место сразу слева от них.
- Приложение с подписью ad hoc, скачанное из интернета, попадает в карантин.
  README говорит один раз открыть через правый клик → «Открыть» или
  `xattr -d com.apple.quarantine`.

## План

1. Создать пакет, сначала написать `MultiClockCore` и раннер проверок,
   гонять `swift run multiclock-check`, пока не напечатает `0 failed`.
2. Написать `main.swift`, `Info.plist`, `build.sh`; запустить `./build.sh`;
   пройти ручные проверки с настоящим скриншотом.
3. Написать `README.md` (установка из Releases или сборка, использование,
   как спрятать системные часы), `docs/native-clock.md`, `LICENSE`,
   `.gitignore`.
4. `git init`, коммит, публичный репозиторий на GitHub, push, тег `v1.0.0`,
   приложить `MultiClock-1.0.0.zip`, собранный командой
   `ditto -c -k --keepParent ~/Applications/MultiClock.app MultiClock-1.0.0.zip`.
5. Отчитаться: вывод проверок, скриншот, адреса репозитория и релиза, и что
   пропущено с причиной.
