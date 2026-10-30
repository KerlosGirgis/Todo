<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset=".github/readme/hero-dark.png" />
  <img src=".github/readme/hero-light.png" width="100%" alt="Todo: your tasks and notes, private by design. Three phones showing the app's tasks and notes." />
</picture>

<br />
<br />

[![F-Droid](https://img.shields.io/f-droid/v/com.k.todo?style=flat-square&logo=fdroid&logoColor=white&label=F-Droid&color=1976D2)](https://f-droid.org/packages/com.k.todo/)
[![GitHub release](https://img.shields.io/github/v/release/KerlosGirgis/Todo?style=flat-square&logo=github&label=Release&color=3D5AFE)](https://github.com/KerlosGirgis/Todo/releases/latest)
[![Android 11+](https://img.shields.io/badge/Android-11%2B-3DDC84?style=flat-square&logo=android&logoColor=white)](#install)
[![Made with Flutter](https://img.shields.io/badge/Made_with-Flutter-02569B?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue?style=flat-square)](LICENSE)

**A calm to-do list and notebook for Android that keeps everything on your phone.**<br />
No account, no ads, no tracking, and no internet permission.

<a href="https://f-droid.org/packages/com.k.todo/"><img src="https://fdroid.gitlab.io/artwork/badge/get-it-on-en.svg" alt="Get it on F-Droid" height="80" /></a>
<a href="https://github.com/KerlosGirgis/Todo/releases/latest"><img src=".github/readme/get-it-on-github.png" alt="Get it on GitHub" height="80" /></a>

</div>

## Features

<table>
  <tr>
    <td align="center" valign="top" width="33%">
      <img src=".github/readme/feature-reminders.png" width="64" alt="" /><br />
      <b>Reminders</b><br />
      Get reminded about a task once, or every day.
    </td>
    <td align="center" valign="top" width="33%">
      <img src=".github/readme/feature-streaks.png" width="64" alt="" /><br />
      <b>Daily streaks</b><br />
      Daily tasks start fresh each day, with your week and streak on the card.
    </td>
    <td align="center" valign="top" width="33%">
      <img src=".github/readme/feature-rich-text.png" width="64" alt="" /><br />
      <b>Rich-text notes</b><br />
      Headings, checklists, lists, quotes, code, links, and highlights.
    </td>
  </tr>
  <tr>
    <td align="center" valign="top" width="33%">
      <img src=".github/readme/feature-covers.png" width="64" alt="" /><br />
      <b>Colorful covers</b><br />
      Give each note a color of its own, and its card previews what's inside.
    </td>
    <td align="center" valign="top" width="33%">
      <img src=".github/readme/feature-app-lock.png" width="64" alt="" /><br />
      <b>App Lock</b><br />
      Lock the app with your fingerprint or a password, and lock any note on its own.
    </td>
    <td align="center" valign="top" width="33%">
      <img src=".github/readme/feature-private.png" width="64" alt="" /><br />
      <b>Stays on your phone</b><br />
      An encrypted database, encrypted backups, and no internet permission.
    </td>
  </tr>
</table>

## Screenshots

<p align="center">
  <img src="metadata/en-US/images/phoneScreenshots/1.png" width="30%" alt="To-do list with a progress ring, filters, and tasks with reminders" />
  <img src="metadata/en-US/images/phoneScreenshots/2.png" width="30%" alt="Notes with colorful covers and previews of their formatting" />
  <img src="metadata/en-US/images/phoneScreenshots/3.png" width="30%" alt="A note with headings, a checklist, bullets, a highlight, and a quote" />
</p>
<p align="center">
  <img src="metadata/en-US/images/phoneScreenshots/4.png" width="30%" alt="The formatting panel: text styles, lists, quotes, code, and highlights" />
  <img src="metadata/en-US/images/phoneScreenshots/5.png" width="30%" alt="App Lock asking for a password" />
  <img src="metadata/en-US/images/phoneScreenshots/8.png" width="30%" alt="The to-do list in the light theme" />
</p>

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

<details>
<summary><b>Signing a release build</b></summary>
<br />

Release builds are signed by the [release workflow](.github/workflows/release.yml) when a version tag is pushed. To sign your own, [make a keystore](https://docs.flutter.dev/deployment/android#sign-the-app), save it as `android/app/kkey.keystore`, and set `ANDROID_KEYSTORE_PASSWORD`, `RELEASE_KEY_ALIAS`, and `ANDROID_KEY_ALIAS_PASSWORD` before you run `flutter build apk --release`.

</details>

## Contributing

Found a bug or have an idea? [Open an issue](https://github.com/KerlosGirgis/Todo/issues). Pull requests are welcome too.

## License

Todo is free software, released under the [GNU General Public License v3.0](LICENSE).

<br />

<p align="center">Developed with ❤️ by <a href="https://github.com/KerlosGirgis">Kerlos Girgis</a></p>
