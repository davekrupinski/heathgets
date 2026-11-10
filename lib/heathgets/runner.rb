require "date"

module Heathgets
  class Runner
    def initialize(store:, fetcher: Fetcher.new, logger: Heathgets.logger, pause: 2, today: -> { Date.today })
      @store = store
      @fetcher = fetcher
      @log = logger
      @pause = pause
      @today = today
    end

    # Normal daily run. Starts at the newest strip and walks back until it
    # reaches a day that's already saved, or `days` days back. A short
    # outage of the NUC or NAS fills itself in on the next run.
    def catch_up(days: 7)
      cutoff = @today.call - (days - 1)
      walk(from: cutoff, stop_at_existing: true)
    end

    # One-off: fetch every strip between `from` and `to` (inclusive) that
    # isn't saved yet.
    def backfill(from:, to: @today.call)
      walk(from: from, to: to, stop_at_existing: false)
    end

    private

    def walk(from:, to: nil, stop_at_existing:)
      @store.check!
      saved = 0
      page = @fetcher.latest

      while page && page.date >= from
        if to && page.date > to
          # Newer than the requested range: keep walking back.
        elsif @store.exists?(page.date)
          @log.info("#{page.date} exists, skipping")
          break if stop_at_existing
        else
          image = @fetcher.image(page.image_url)
          path = @store.save(date: page.date, image: image, image_url: page.image_url)
          @log.info("#{page.date} saved #{path} (#{image.bytes.bytesize} bytes)")
          saved += 1
        end

        break unless page.prev_url
        sleep @pause
        page = @fetcher.page(page.prev_url)
      end

      @log.info("done: #{saved} new strip(s)")
      saved
    end
  end
end
