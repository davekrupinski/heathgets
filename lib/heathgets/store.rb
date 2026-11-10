require "fileutils"
require "json"
require "time"
require "securerandom"

module Heathgets
  # Layout under the data root (the NAS share):
  #
  #   .heathgets                         marker: proves the share is mounted
  #   heathcliff/2026/2026-11-09.jpg     permanent archive, one file per day
  #   heathcliff/latest.jpg              newest strip, fixed name
  #   heathcliff/latest.json             {date, file, image_url, fetched_at}
  class Store
    MARKER = ".heathgets".freeze
    COMIC = "heathcliff".freeze

    attr_reader :root

    def initialize(root)
      @root = File.expand_path(root)
    end

    # Creates the marker. Run once, by hand, against the real share.
    def init!
      FileUtils.mkdir_p(comic_dir)
      File.write(File.join(root, MARKER), "heathgets data root\n")
    end

    # Refuses to run unless the marker is present. If the NAS isn't mounted,
    # the mountpoint is an empty local directory, and writing there would
    # quietly fill the NUC's own disk instead of the share.
    def check!
      raise Error, "data root #{root} does not exist" unless Dir.exist?(root)
      unless File.exist?(File.join(root, MARKER))
        raise Error, "#{root}/#{MARKER} is missing. Is the NAS share mounted? " \
                     "(first time: run `heathgets init`)"
      end
      raise Error, "data root #{root} is not writable" unless File.writable?(root)
    end

    def exists?(date)
      !Dir.glob(File.join(year_dir(date), "#{date.iso8601}.*")).empty?
    end

    def archive_path(date, ext)
      File.join(year_dir(date), "#{date.iso8601}.#{ext}")
    end

    # Returns the archive path written.
    def save(date:, image:, image_url:)
      path = archive_path(date, image.extension)
      FileUtils.mkdir_p(File.dirname(path))
      atomic_write(path, image.bytes)
      update_latest(date, image, image_url, path) if newer_than_latest?(date)
      path
    end

    def latest_date
      data = JSON.parse(File.read(latest_json_path))
      Date.iso8601(data.fetch("date"))
    rescue Errno::ENOENT, JSON::ParserError, KeyError, Date::Error
      nil
    end

    private

    def newer_than_latest?(date)
      current = latest_date
      current.nil? || date >= current
    end

    def update_latest(date, image, image_url, archive_path)
      latest = File.join(comic_dir, "latest.#{image.extension}")
      atomic_write(latest, image.bytes)
      # Remove a stale latest.<other-ext> if the image format changed.
      Dir.glob(File.join(comic_dir, "latest.*")).each do |f|
        File.delete(f) unless f == latest || f == latest_json_path
      end
      atomic_write(latest_json_path, JSON.pretty_generate(
        date: date.iso8601,
        file: archive_path.delete_prefix("#{root}/"),
        latest_file: latest.delete_prefix("#{root}/"),
        image_url: image_url,
        fetched_at: Time.now.utc.iso8601
      ) + "\n")
    end

    # Write to a temp file in the same directory, then rename. Readers never
    # see a half-written file, even over SMB/NFS.
    def atomic_write(path, data)
      tmp = File.join(File.dirname(path), ".#{File.basename(path)}.#{SecureRandom.hex(4)}.tmp")
      File.binwrite(tmp, data)
      File.rename(tmp, path)
    ensure
      File.delete(tmp) if tmp && File.exist?(tmp)
    end

    def comic_dir
      File.join(root, COMIC)
    end

    def year_dir(date)
      File.join(comic_dir, date.year.to_s)
    end

    def latest_json_path
      File.join(comic_dir, "latest.json")
    end
  end
end
