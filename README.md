# backup\_icloud\_notes

## Backup iCloud notes

This script backs up your notes saved in iCloud using [`apple_cloud_notes_parser`](https://github.com/ggilder/apple_cloud_notes_parser).
It uses git to maintain revision history in the backup directory, so that previous revisions to notes are encapsulated within the backup.

Currently, backing up attachments (images, sounds, etc.) with notes is not supported.

## Usage

`./backup_icloud_notes.rb PATH_TO_APPLE_CLOUD_NOTES_PARSER BACKUP_DESTINATION_DIRECTORY`

The `-v` or `--verbose` flag may be added to turn on more verbose output.

## Limitations

- TBD after experimenting more with `apple_cloud_notes_parser` to verify what Notes features are supported.
