> [!NOTE]
> major cleanup in progress, excuse the mess in here at the moment

## To generate sights using the included data files

  1. Run FCS.exe
  2. Select your sight type, options, language, and settings
  3. Click "Make Sights"
  4. Copy the output files from `UserSights` to your War Thunder install's `UserSights` folder (e.g. `C:\Program Files (x86)\Steam\steamapps\common\War Thunder\UserSights`) - or just set the output path directly to that folder in FCS settings if you want.

## Updating data files from your local install

The included data files are manually updated and may be out of date. Data extraction will be moved into the actual tool soon, but in the meantime you can use the provided PowerShell script `Update-Datamine.ps1` along with the `wt_ext_cli` tool to extract the latest data files from your install.

  1. Download the wt_ext_cli binary from [Warthunder-Open-Source-Foundation/wt_ext_cli/releases](https://github.com/Warthunder-Open-Source-Foundation/wt_ext_cli/releases) (needed to extract the `.vromfs.bin` files) and place it on your PATH or next to Update-Datamine.ps1
  2. Run the Update-Datamine.ps1 script - it will attempt to auto-detect your War Thunder install path, but will ask if it fails. You can also specify the install path manually by running it with `-InstallPath "C:\Path\To\WarThunder"`
  3. Launch FCS.exe and click "Convert Datamine" → "Make Ballistic"
  4. Proceed as normal with "Make Sights"

You can also downloaded the pre-extracted datamine files from [gszabi99/War-Thunder-Datamine](https://github.com/gszabi99/War-Thunder-Datamine) (which also uses wt_ext_cli for extraction) and point the Datamine path to that folder in FCS.exe

> [!NOTE]
> ignore.txt filters out event/non-playable vehicles to avoid increasing load times with unusable sight files. If downloaded from the above repo you may want to remove the files listed in ignore.txt from `aces.vromfs.bin_u/gamedata/units/tankmodels` yourself, or just ignore them if you don't care about the extra sight generation/load time.

If something breaks (there are many things that can break at the moment), you can yell at the professional customer support team (me) in the [Discord](https://discord.gg/XrTMMQ6R) and I can probably fix it.

Original README below - to be updated; instructions may be outdated (it should just werk with the default paths now) but still some useful information

```txt
**************************************
*** FCS MANAGER VERSION 1.6.231215 ***
**************************************

***************** EN *****************

* How to change the language, color or other settings?
  1) Run the program
  2) If the program is in the same directory as the folders "Localisation", "Ballistic", "Data",
  then go to the next step. Otherwise, specify the path to each directory.
  1) In the "UserSights" specify the folder UserSights from the directory of the game, in this case, all the sights will be loaded there.
  2) In the "Language" list select language.
  3) In the "Sight type" list, select sight.
  4) In the window below, select the sight subtypes.
  5) In the list below, select the playing countries.
  6) If necessary, you can change some settings in "Advanced Settings".
  7) Click the "Make sight" button.

 * Additional settings:
  - "Sensitivity" is determined by the "Mouse Wheel Multiplier" of the game. By default 50%.
  If you change this setting, you must recalculate the ballistics! To do this, press the "Make ballistic" button.
  The ballistics of all projectiles are counted up to 4 km (in some cases less).

  Made by: assin127 (Discord)

***************** RU *****************

 * Как сменить язык, цвет и другие настройки?
  1) Запустить программу
  2) Если программа находится в той же директории, что и папки Localisation, Ballistic, Data,
  то переходим к следующему пункту. В противном случае указываем путь до каждой директории.
  3) В графе UserSights указываем папку UserSights из директории игры, в этом случае все прицелы сразу загрузятся туда.
  4) В списке Language выбираем язык.
  5) В списке Sight type указываем прицел.
  6) В окне ниже выбираем подтипы прицела.
  7) В списке ниже указываем игровые страны.
  8) При необходимости можно изменить некоторые настройки в Advanced Settings.
  9) Нажать кнопку "Make sight".

 * Дополнительные настройки:
  - Sensitivity определяется "Множителем колеса мыши" игры. По умолчанию 50%.
  При изменении этого параметра необходимо пересчитать баллистику! Для этого требуется нажать кнопку Make ballistic.
  Баллистика всех снарядов считается до 4 км (в некоторых случаях меньше).

  Разработчик: assin127 (Discord)
```
