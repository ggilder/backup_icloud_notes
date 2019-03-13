#!/usr/bin/env ruby

require "rubygems"
require "bundler"

Bundler.require

require "fileutils"
require "cgi"

backup_destination = "/Users/gabriel/Desktop/notes_backup"

notes_app = Appscript.app('Notes')
folders = notes_app.folders.get
folders = folders.reject { |folder| folder.name.get == "Recently Deleted" }

# TODO - delete all existing notes first, then save, so that deletions are caught

notes_count = 0
puts "Backing up #{folders.count} folders"
folders.each do |folder|
  folder_name = folder.name.get
  puts "Creating folder #{folder_name}"
  FileUtils.mkdir_p(File.join(backup_destination, folder_name))
  puts "Backing up #{folder.notes.count} notes"
  folder.notes.get.each do |note|
    note_name = note.name.get
    note_file_name = note.modification_date.get.strftime('%Y-%m-%d ') + note_name.gsub(%r([/:]), "-") + ".html"
    note_path = File.join(backup_destination, folder_name, note_file_name)

    html = note.body.get
    html = "<h1>#{CGI.escapeHTML(note_name)}</h1>\n<p>Created: #{note.creation_date.get}<br>Modified: #{note.modification_date.get}</p>\n" + html

    puts "Backing up #{note_name} to #{note_file_name}"
    File.write(note_path, html)
    notes_count += 1

    # TODO:
    # - Warn on attachments
    # - Possibly warn on file name collision? Would need to delete first then
  end
end

puts
puts "Backed up #{notes_count} notes."
