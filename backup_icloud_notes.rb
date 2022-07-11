#!/usr/bin/env ruby

# Allows the script to work (i.e. load Bundler dependencies) even when run from
# a different working directory
Dir.chdir(File.dirname(File.realpath(__FILE__)))

require "rubygems"
require "bundler"

Bundler.require

require "fileutils"
require "cgi"
require "open3"
require "time"

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

def osascript(script)
  out, err, status = Open3.capture3("osascript", stdin_data: script)
  if status.success?
    return out.chomp
  else
    raise RuntimeError, err
  end
end

# Functions for getting formatted note data in the jankiest possible way
def get_note_rtf(note_query)
  osascript(%{tell application "Notes" to activate})
  osascript(%{tell application "Notes" to show #{note_query}})
  script = <<EOD
  tell application "System Events"
        tell process "Notes"
                click menu item "Float Selected Note" of menu "Window" of menu bar 1
                click menu item "Select All" of menu "Edit" of menu bar 1
                click menu item "Copy" of menu "Edit" of menu bar 1
        end tell
  end tell

  tell application "Notes"
          close front window
          get (the clipboard as «class RTF »)
  end tell
EOD
  out = osascript(script)
  return out.match(/«data RTF ([0-9A-F]+)»/)[1].scan(/../).map { |x| x.hex }.pack('c*')
end

def rtf_to_html(rtf_data)
  out, err, status = Open3.capture3(*%w(textutil -stdin -stdout -convert html -format rtf), stdin_data: rtf_data)
  if status.success?
    return out
  else
    raise RuntimeError, err
  end
end

def get_count(query)
  script = %{tell application "Notes" to get count of #{query}}
  out = osascript(script)
  out.to_i
end

def get_text(query)
  script = %{tell application "Notes" to get #{query}}
  osascript(script)
end

def get_date(query)
  script = %{tell application "Notes" to get #{query}}
  out = osascript(script)
  DateTime.parse(out.sub(/^date /, ""))
end


######################### Execution ######################

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

# Fail if any pre-existing changes
if git_repo_dirty(git_repo)
  puts "Repo is not in a clean state!"
  exit(1)
end

# Delete existing notes so deletions will be caught
File.delete(*Dir[File.join(backup_destination, "**", "*.html")])


folder_count = get_count("folders")
folder_names = (1..folder_count).map { |n| get_text("name of folder #{n}") }
folder_names.reject! { |name| name == "Recently Deleted" }

notes_count = 0
notes_with_attachments = []
puts "Backing up #{folder_names.count} folders"
folder_names.each do |folder_name|
  notes_count = get_count(%{notes in folder "#{folder_name}"})
  puts %{Backing up #{notes_count} notes in folder "#{folder_name}"}
  FileUtils.mkdir_p(File.join(backup_destination, folder_name))
  (1..notes_count).each do |note_idx|
    note_query = %{note #{note_idx} of folder "#{folder_name}"}
    note_name = get_text(%{name of #{note_query}})
    creation_date = get_date(%{creation date of #{note_query}})
    mod_date = get_date(%{modification date of #{note_query}})
    note_file_name = mod_date.strftime('%Y-%m-%d ') + note_name.gsub(%r([/:]), "-") + ".html"
    note_path = File.join(backup_destination, folder_name, note_file_name)
    if File.exist?(note_path)
      $stderr.puts %{File name collision: "#{note_path}" already exists!}
      exit 1
    end

    html = rtf_to_html(get_note_rtf(note_query))
    html.sub!(/<body>/, "<body>\n<p>Created: #{creation_date}<br>Modified: #{mod_date}</p>")

    if verbose
      puts %{Backing up "#{note_name}" to "#{note_file_name}"}
    end
    File.write(note_path, html)
    notes_count += 1

    attachments_count = get_count("attachments of #{note_query}")
    if attachments_count > 0
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
  puts "Pushing changes"
  git_repo.push
else
  puts "No changes to commit."
end

puts
puts "Backed up #{notes_count} notes."
if notes_with_attachments.count > 0
  puts "#{notes_with_attachments.count} notes have attachments which cannot currently be backed up."
end
