require_relative "test_helper"

class RunnerTest < Minitest::Test
  # Serves a chain of pages, newest first, without touching the network.
  class FakeFetcher
    attr_reader :page_requests, :image_requests

    def initialize(dates)
      @pages = dates.each_with_index.map do |d, i|
        Heathgets::Fetcher::Page.new(url: "p#{i}", date: d, image_url: "img-#{d}",
                                     prev_url: i + 1 < dates.size ? "p#{i + 1}" : nil)
      end
      @page_requests = 0
      @image_requests = []
    end

    def latest = page("p0")

    def page(url)
      @page_requests += 1
      @pages.find { _1.url == url }
    end

    def image(url)
      @image_requests << url
      jpeg(url)
    end
  end

  def setup
    @dir = Dir.mktmpdir
    @store = Heathgets::Store.new(@dir).tap(&:init!)
    @today = Date.new(2026, 11, 9)
    @fetcher = FakeFetcher.new((0..30).map { @today - _1 })
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def runner = Heathgets::Runner.new(store: @store, fetcher: @fetcher, pause: 0, today: -> { @today })

  def test_first_run_fetches_window
    assert_equal 7, runner.catch_up(days: 7)
    assert @store.exists?(@today)
    assert @store.exists?(@today - 6)
    refute @store.exists?(@today - 7)
    assert_equal @today, @store.latest_date
  end

  def test_stops_at_first_existing_day
    @store.save(date: @today - 3, image: jpeg, image_url: "u")

    assert_equal 3, runner.catch_up(days: 7)
    assert_equal %w[img-2026-11-09 img-2026-11-08 img-2026-11-07], @fetcher.image_requests
    assert_equal 4, @fetcher.page_requests
  end

  def test_up_to_date_run_fetches_no_images
    @store.save(date: @today, image: jpeg, image_url: "u")
    assert_equal 0, runner.catch_up
    assert_empty @fetcher.image_requests
    assert_equal 1, @fetcher.page_requests
  end

  def test_backfill_range_fills_gaps_and_keeps_latest
    @store.save(date: @today, image: jpeg("today"), image_url: "u")
    @store.save(date: Date.new(2026, 10, 25), image: jpeg, image_url: "u")

    assert_equal 4, runner.backfill(from: Date.new(2026, 10, 23), to: Date.new(2026, 10, 27))
    (23..27).each { |d| assert @store.exists?(Date.new(2026, 10, d)) }
    refute @store.exists?(Date.new(2026, 10, 28))
    assert_equal @today, @store.latest_date
  end

  def test_refuses_without_marker
    File.delete(File.join(@dir, ".heathgets"))
    assert_raises(Heathgets::Error) { runner.catch_up }
    assert_equal 0, @fetcher.page_requests
  end
end
