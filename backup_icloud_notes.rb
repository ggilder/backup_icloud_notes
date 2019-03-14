#!/usr/bin/env ruby

require "rubygems"
require "bundler"

Bundler.require

require "fileutils"
require "cgi"

# TODO:
# - Refactor esp. interactions around git repo

verbose = !([ARGV.delete('-v'), ARGV.delete('--verbose')].compact.empty?)

backup_destination = ARGV.shift
if !File.directory?(backup_destination) || !File.writable?(backup_destination)
  $stderr.puts "Backup destination must be a writable directory!"
  exit 1
end

git_dir = File.join(backup_destination, ".git")
git_repo = if !File.directory?(git_dir)
  puts "Git repository not present in backup destination; initializing"
  Git.init(backup_destination)
else
  Git.open(backup_destination)
end

def new_git_repo(repo)
  repo.object('HEAD')
  return false
rescue Git::GitExecuteError
  return true
end

def git_repo_dirty(repo)
  if new_git_repo(repo)
    repo.lib.ls_files(%w(-o --exclude-standard)).count > 0
  else
    repo.status.untracked.count > 0 ||
      repo.status.changed.count > 0 ||
      repo.status.added.count > 0 ||
      repo.status.deleted.count > 0
  end
end

# Commit any existing changes
if git_repo_dirty(git_repo)
  puts "Committing pre-existing changes"
  git_repo.add(all: true)
  git_repo.commit("Backup pre-existing changes")
end

# Delete existing notes so deletions will be caught
File.delete(*Dir[File.join(backup_destination, "**", "*.html")])

notes_app = Appscript.app('Notes')
folders = notes_app.folders.get
folders = folders.reject { |folder| folder.name.get == "Recently Deleted" }

notes_count = 0
notes_with_attachments = []
puts "Backing up #{folders.count} folders"
folders.each do |folder|
  folder_name = folder.name.get
  puts %{Backing up #{folder.notes.count} notes in folder "#{folder_name}"}
  FileUtils.mkdir_p(File.join(backup_destination, folder_name))
  folder.notes.get.each do |note|
    note_name = note.name.get
    note_file_name = note.modification_date.get.strftime('%Y-%m-%d ') + note_name.gsub(%r([/:]), "-") + ".html"
    note_path = File.join(backup_destination, folder_name, note_file_name)
    if File.exist?(note_path)
      $stderr.puts %{File name collision: "#{note_path}" already exists!}
      exit 1
    end

    html = note.body.get
    html = "<h1>#{CGI.escapeHTML(note_name)}</h1>\n<p>Created: #{note.creation_date.get}<br>Modified: #{note.modification_date.get}</p>\n" + html

    if verbose
      puts %{Backing up "#{note_name}" to "#{note_file_name}"}
    end
    File.write(note_path, html)
    notes_count += 1

    if note.attachments.count > 0
      $stderr.puts %{[WARNING] Note "#{note_name}" has attachments, which cannot currently be backed up!}
      notes_with_attachments << note_name
    end
  end
end

# Work around bug with cached index in git gem
begin
  git_repo.lib.send(:command_lines, 'update-index', ['--refresh'])
rescue
  # The update-index command can fail, no big deal
end

puts
puts "Status:"
if new_git_repo(git_repo)
  puts "(new repo, no status to show)"
else
  puts "New: #{git_repo.status.untracked.count}"
  puts "Changed: #{git_repo.status.changed.count}"
  puts "Deleted: #{git_repo.status.deleted.count}"
end

puts
if git_repo_dirty(git_repo)
  puts "Committing latest backup"
  git_repo.add(all: true)
  git_repo.commit("Backup notes")
else
  puts "No changes to commit."
end

puts
puts "Backed up #{notes_count} notes."
if notes_with_attachments.count > 0
  puts "#{notes_with_attachments.count} notes have attachments which cannot currently be backed up."
end
