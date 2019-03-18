# backup\_icloud\_notes

## Backup iCloud notes by scripting the macOS Notes app

This script backs up your notes saved in iCloud (or locally on your computer) using the macOS Notes app's (very limited) AppleScript support. It uses git to maintain revision history in the backup directory, so that previous revisions to notes are encapsulated within the backup.

Currently, backing up attachments (images, sounds, etc.) with notes is not supported. Any notes that contain attachments will result in a warning.

## Usage

`./backup_icloud_notes.rb BACKUP_DESTINATION_DIRECTORY`

The `-v` or `--verbose` flag may be added to turn on more verbose output.

## Limitations

Notes.app does not provide the full content of a note in its AppleScript API. Here are the limitations I've discovered so far:

- Links are not supported; only the link text is exported
- Attachments are not supported
- Line breaks (i.e. breaks created with shift-return) are stripped on export
