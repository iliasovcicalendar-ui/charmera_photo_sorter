# Photo Sorter

A tiny Windows app for importing photos from a Charmera camera and reviewing them one at a time.

- Left and right arrows browse the photos.
- Up moves the current photo to your memories folder.
- Down moves the current photo to the Windows Recycle Bin.
- The on-screen buttons and keyboard arrow keys do the same things.
- An optional Task Scheduler rule imports new photos whenever the camera connects.

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
  "memoriesFolder": "%USERPROFILE%\\Pictures\\memories",
  "cameraVolumeLabel": "Charmera",
  "cameraPhotoFolder": "DCIM"
}
```

- `sourceFolder` is the folder containing photos waiting to be sorted. The automatic importer creates it if needed; otherwise create it before starting Photo Sorter.
- `memoriesFolder` receives photos when you press Up. The app creates this folder automatically if it does not exist.
- `cameraVolumeLabel` is the name Windows shows for the connected camera drive.
- `cameraPhotoFolder` is the photo folder on that drive.
- Down sends a photo to the Windows Recycle Bin, so no trash folder needs to be configured.

`%USERPROFILE%` means your Windows user folder. For example, `%USERPROFILE%\\Pictures\\unsorted` works for every user without putting their username in the config file.

You can also use complete paths. In JSON, each backslash must be written twice:

```json
{
  "sourceFolder": "D:\\Photos\\To Sort",
  "memoriesFolder": "D:\\Photos\\Memories",
  "cameraVolumeLabel": "Charmera",
  "cameraPhotoFolder": "DCIM"
}
```

Paths relative to the app folder also work, such as `"photos"` or `"..\\photos"`.

## Test camera importing manually

Connect the camera and check in File Explorer that its drive is named **Charmera** and contains a **DCIM** folder. If the names differ, update `cameraVolumeLabel` or `cameraPhotoFolder` in `config.json`.

Open PowerShell in the Photo Sorter folder and run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Import-Charmera.ps1"
```

The command copies new supported photos from the camera into `sourceFolder`, prints a summary, and exits. The camera's own files are not deleted.

The app records each successfully copied photo in `downloaded-photos.txt`. It compares the camera path, file size, and timestamp rather than only the filename, so reconnecting the camera will not import the same photo again. Keep this file if you move or update the app.

If the destination already contains a different photo with the same filename, the imported photo receives a number such as `PICT0001 (2).jpg`.

## Check automatically with Task Scheduler

Some PCs do not record a usable camera-arrival event. A reliable alternative is to let Task Scheduler run the importer once per minute. When Charmera is absent, the script checks the available drives and exits immediately. When it is present, new photos are copied.

1. Open the Start menu, search for **Task Scheduler**, and select **Create Task** in the right-hand panel.
2. On **General**, name it `Photo Sorter - Import Charmera` and select **Run only when user is logged on**. Administrator privileges are not required.
3. On **Triggers**, select **New**.
4. For **Begin the task**, choose **At log on** and select **Specific user**, using your Windows account.
5. Under **Advanced settings**, select **Repeat task every** and choose **1 minute**. Set **for a duration of** to **Indefinitely**, then select **OK**.
6. On **Actions**, select **New** and choose **Start a program**.
7. In **Program/script**, enter:

    ```text
    wscript.exe
    ```

8. In File Explorer, open the Photo Sorter folder, select the address bar, and copy the folder's full path. In **Add arguments**, enter that path followed by the launcher filename, keeping the quotation marks:

    ```text
    "PASTE_THE_PHOTO_SORTER_FOLDER_PATH_HERE\Run Import Hidden.vbs"
    ```

9. In **Start in**, paste the Photo Sorter folder path itself without quotation marks:

    ```text
    PASTE_THE_PHOTO_SORTER_FOLDER_PATH_HERE
    ```

10. On **Conditions**, clear **Start the task only if the computer is on AC power** if you also want imports while using a laptop battery.
11. On **Settings**, keep **Allow task to be run on demand** selected. For **If the task is already running**, choose **Do not start a new instance**.
12. Select **OK** to save the task.

To verify it, connect Charmera and wait up to one minute. New photos should appear in `sourceFolder`, and the task's **Last Run Result** should be `0x0`. You can also right-click the task and select **Run** while the camera is connected.

`Run Import Hidden.vbs` launches PowerShell without creating a visible console window, so the scheduled check will not interrupt your work.

To disable automatic importing later, open **Task Scheduler > Task Scheduler Library**, find **Photo Sorter - Import Charmera**, and disable or delete it.

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
