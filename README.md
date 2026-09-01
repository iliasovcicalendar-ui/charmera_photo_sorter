# Photo Sorter

A tiny Windows app for reviewing a folder of photos one at a time.

- Left and right arrows browse the photos.
- Up moves the current photo to your memories folder.
- Down moves the current photo to the Windows Recycle Bin.
- The on-screen buttons and keyboard arrow keys do the same things.

## Requirements

- Windows 10 or Windows 11
- No installation, package manager, or additional software is required.

## Download from GitHub

### Option 1: Download ZIP

1. Open the repository on GitHub.
2. Select **Code**, then **Download ZIP**.
3. Extract the ZIP somewhere on your computer.

### Option 2: Clone with Git

```powershell
git clone https://github.com/iliasovcicalendar-ui/charmera_photo_sorter.git
```

## Set up the folders

Open `config.json` in Notepad. It initially contains:

```json
{
  "sourceFolder": "%USERPROFILE%\\Pictures\\charmera_dump",
  "memoriesFolder": "%USERPROFILE%\\Pictures\\memories"
}
```

- `sourceFolder` is the folder containing photos waiting to be sorted. This folder must exist before the app starts.
- `memoriesFolder` receives photos when you press Up. The app creates this folder automatically if it does not exist.
- Down sends a photo to the Windows Recycle Bin, so no trash folder needs to be configured.

`%USERPROFILE%` means your Windows user folder. For example, `%USERPROFILE%\\Pictures\\unsorted` works for every user without putting their username in the config file.

You can also use complete paths. In JSON, each backslash must be written twice:

```json
{
  "sourceFolder": "D:\\Photos\\To Sort",
  "memoriesFolder": "D:\\Photos\\Memories"
}
```

Paths relative to the app folder also work, such as `"photos"` or `"..\\photos"`.

## Run the app

Double-click **Start Photo Sorter.bat**.

If Windows displays a security warning after downloading the app, select **More info**, confirm that the files came from the GitHub repository you intended to download, and then select **Run anyway**.

## Controls

| Key | Action |
| --- | --- |
| Left | Previous photo |
| Right | Next photo |
| Up | Move photo to the configured memories folder |
| Down | Move photo to the Windows Recycle Bin |

The app recognizes JPG, JPEG, PNG, GIF, BMP, TIFF, and WebP files that Windows can decode.

If a file with the same name already exists in the memories folder, Photo Sorter keeps both by adding a number to the moved photo's name.
