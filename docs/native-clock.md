# Hiding the macOS system clock / Как спрятать системные часы

macOS (Big Sur and later) does not allow removing the clock from the menu bar.
The smallest it gets is an analog dial without date or weekday. That is the
"after" state in the screenshots.

| Before | After |
|---|---|
| ![before](images/before.png) | ![after](images/after.png) |

## GUI

System Settings → Control Center → scroll to **Clock** → **Clock Options…**

| Setting | Value |
|---|---|
| Style | Analog |
| Show date | Never |
| Show the day of the week | off |

## Terminal

```sh
defaults write com.apple.menuextra.clock IsAnalog -bool true
defaults write com.apple.menuextra.clock ShowDate -int 2
defaults write com.apple.menuextra.clock ShowDayOfWeek -bool false
killall ControlCenter
```

## Undo

```sh
defaults write com.apple.menuextra.clock IsAnalog -bool false
defaults write com.apple.menuextra.clock ShowDate -int 1
defaults write com.apple.menuextra.clock ShowDayOfWeek -bool true
killall ControlCenter
```

## Placing MultiClock next to it

Hold ⌘ and drag the `DE … MSK …` text to the right. The system clock and
Control Center are pinned and cannot be passed. After a reinstall under a new
bundle identifier macOS forgets the position; drag once more.

---

macOS не даёт убрать свои часы из строки меню. Минимум, которого можно
добиться: аналоговый кружок без даты и дня недели. Путь: Системные настройки →
Пункт управления → Часы → Параметры часов: стиль «Аналоговые», дата «Никогда»,
день недели выключен. Команды для терминала и откат выше. Чтобы поставить
MultiClock вплотную к кружку, зажмите ⌘ и перетащите текст вправо.
