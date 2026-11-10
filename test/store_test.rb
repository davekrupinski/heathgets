require_relative "test_helper"

class StoreTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
    @store = Heathgets::Store.new(@dir)
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def test_check_requires_marker
    assert_raises(Heathgets::Error) { @store.check! }
    @store.init!
    @store.check!
  end

  def test_check_fails_when_root_missing
    assert_raises(Heathgets::Error) { Heathgets::Store.new(File.join(@dir, "nope")).check! }
  end

  def test_save_writes_archive_and_latest
    path = @store.save(date: Date.new(2026, 11, 9), image: jpeg("a"), image_url: "u")

    assert_equal File.join(@dir, "heathcliff/2026/2026-11-09.jpg"), path
    assert_equal "JPEG-a", File.binread(path)
    assert_equal "JPEG-a", File.binread(File.join(@dir, "heathcliff/latest.jpg"))
    meta = JSON.parse(File.read(File.join(@dir, "heathcliff/latest.json")))
    assert_equal "2026-11-09", meta["date"]
    assert_equal "heathcliff/2026/2026-11-09.jpg", meta["file"]
    assert @store.exists?(Date.new(2026, 11, 9))
    refute @store.exists?(Date.new(2026, 11, 8))
    assert_empty Dir.glob(File.join(@dir, "**/*.tmp"), File::FNM_DOTMATCH)
  end

  def test_older_save_does_not_clobber_latest
    @store.save(date: Date.new(2026, 11, 9), image: jpeg("new"), image_url: "u")
    @store.save(date: Date.new(2026, 11, 1), image: jpeg("old"), image_url: "u")

    assert_equal "JPEG-new", File.binread(File.join(@dir, "heathcliff/latest.jpg"))
    assert_equal Date.new(2026, 11, 9), @store.latest_date
    assert @store.exists?(Date.new(2026, 11, 1))
  end

  def test_format_change_removes_stale_latest
    @store.save(date: Date.new(2026, 11, 8), image: jpeg, image_url: "u")
    png = Heathgets::Fetcher::Image.new(bytes: "PNG", content_type: "image/png", extension: "png")
    @store.save(date: Date.new(2026, 11, 9), image: png, image_url: "u")

    latest = Dir.children(File.join(@dir, "heathcliff")).grep(/\Alatest/).sort
    assert_equal %w[latest.json latest.png], latest
  end
end
