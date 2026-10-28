<div align="center">

<img src="metadata/en-US/images/icon.png" width="112" alt="Todo app icon" />

# Todo

**Your tasks and notes, private by design.**

A calm, simple to-do list and notebook for Android that keeps everything on your phone.<br>
No account, no ads, no tracking, and no internet permission.

[![F-Droid](https://img.shields.io/f-droid/v/com.k.todo?logo=fdroid&logoColor=white&label=F-Droid&color=1976D2)](https://f-droid.org/packages/com.k.todo/)
[![GitHub release](https://img.shields.io/github/v/release/KerlosGirgis/Todo?logo=github&label=Release)](https://github.com/KerlosGirgis/Todo/releases/latest)
[![Android 11+](https://img.shields.io/badge/Android-11%2B-3DDC84?logo=android&logoColor=white)](#install)
[![Made with Flutter](https://img.shields.io/badge/Made_with-Flutter-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue)](LICENSE)

<a href="https://f-droid.org/packages/com.k.todo/"><img src="https://fdroid.gitlab.io/artwork/badge/get-it-on-en.svg" alt="Get it on F-Droid" height="80" /></a>

</div>

<p align="center">
  <img src="metadata/en-US/images/phoneScreenshots/1.png" width="23%" alt="To-do list with a progress ring, filters, and tasks with reminders" />
  <img src="metadata/en-US/images/phoneScreenshots/2.png" width="23%" alt="Notes with colorful covers and previews of their formatting" />
  <img src="metadata/en-US/images/phoneScreenshots/3.png" width="23%" alt="A note with headings, a checklist, bullets, a highlight, and a quote" />
  <img src="metadata/en-US/images/phoneScreenshots/4.png" width="23%" alt="The formatting panel: text styles, lists, quotes, code, and highlights" />
</p>
<p align="center">
  <img src="metadata/en-US/images/phoneScreenshots/5.png" width="23%" alt="App Lock asking for a password" />
  <img src="metadata/en-US/images/phoneScreenshots/6.png" width="23%" alt="Profile with task progress and the choice of light or dark theme" />
  <img src="metadata/en-US/images/phoneScreenshots/7.png" width="23%" alt="The day's Bible verse, shown under your avatar" />
  <img src="metadata/en-US/images/phoneScreenshots/8.png" width="23%" alt="The to-do list in the light theme" />
</p>

## Features

### ✅ Tasks

- **Reminders.** Give a task a date and a time, and get reminded once or every day.
- **Quick gestures.** Tap a task to check it off, swipe it away to delete it, or press and hold to drag it into place.
- **Your progress at a glance.** A progress ring shows how far along you are, and filters split the list into done and undone.
- **Nothing slips by.** An overdue task's date turns red until it's done.

### 📝 Notes

- **Rich text.** Headings, bold and italic, checklists, bulleted and numbered lists, quotes, code, links, highlights, dividers, and more.
- **Colorful covers.** Give each note its own cover and title color. Cards preview the formatting and show how much of a checklist is done.
- **Find anything.** Search notes by title or by what they say, and arrange them in any order.
- **Write your way.** Notes save as you type. Turn on a live word count, or a relaxed, handwritten font.
- **Home screen widget.** Keep a note on your home screen.

### 🔒 Private and secure

- **Stays on your phone.** Your tasks and notes are kept in an encrypted database. Todo has no internet permission, so your data never leaves your phone unless you export it.
- **App Lock.** Unlock the app with your fingerprint or a password. It locks again after a minute away, and hides its content from the recent apps screen.
- **Locked notes.** Keep individual notes behind your fingerprint.
- **Encrypted backups.** Back up your tasks and notes to password-protected, AES-256 encrypted files, and restore them on any phone.
- **Discreet reminders.** While App Lock is on, reminders don't say which task they're for.

### 🎨 Make it yours

- Light and dark themes.
- One of the built-in avatars, or a photo of your own.
- Open on your tasks or your notes, and choose the text sizes for each.
- A Bible verse for every day, shown when you tap your avatar. You can turn it off.
- A side-by-side layout when you turn your phone sideways.
- Tips that show how each page works, which you can bring back from Settings.

## Install

Get Todo from **[F-Droid](https://f-droid.org/packages/com.k.todo/)** to stay up to date, or download an APK from **[GitHub Releases](https://github.com/KerlosGirgis/Todo/releases/latest)**:

| APK | For |
| --- | --- |
| `app-arm64-v8a-release.apk` | Most phones |
| `app-armeabi-v7a-release.apk` | Older 32-bit phones |
| `app-x86_64-release.apk` | Emulators and x86 devices |

Todo runs on Android 11 and newer.

## Build from source

You'll need [Flutter](https://docs.flutter.dev/get-started/install) 3.47 or newer, with the Android SDK.

```sh
git clone https://github.com/KerlosGirgis/Todo.git
cd Todo
flutter pub get
flutter run
```

Release builds are signed by the [release workflow](.github/workflows/release.yml) when a version tag is pushed. To sign your own, follow Flutter's [signing guide](https://docs.flutter.dev/deployment/android#sign-the-app) and point `signingConfigs.release` in [`android/app/build.gradle`](android/app/build.gradle) at your keystore.

## Contributing

Found a bug or have an idea? [Open an issue](https://github.com/KerlosGirgis/Todo/issues). Pull requests are welcome too.

## License

Todo is free software, released under the [GNU General Public License v3.0](LICENSE).

<br>

<p align="center">Developed with ❤️ by <a href="https://github.com/KerlosGirgis">Kerlos Girgis</a></p>
