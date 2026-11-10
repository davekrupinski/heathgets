require_relative "test_helper"

class FetcherTest < Minitest::Test
  def test_parses_latest_page
    page = Heathgets::Fetcher.parse(fixture("creators_2026-11-09.html"), Heathgets::Fetcher::LATEST_URL)

    assert_equal Date.new(2026, 11, 9), page.date
    assert_equal "https://cdn.alphacomedy.com/19/2026/11_09_26_e85106a242bb15b7043a393773f0af57.jpg", page.image_url
    assert_equal "https://www.creators.com/read/heathcliff/11/26/425098", page.prev_url
  end

  def test_parses_previous_page
    url = "https://www.creators.com/read/heathcliff/11/26/425098"
    page = Heathgets::Fetcher.parse(fixture("creators_2026-11-08.html"), url)

    assert_equal Date.new(2026, 11, 8), page.date
    assert_match %r{/11_08_26_[0-9a-f]+\.jpg\z}, page.image_url
    assert_equal "https://www.creators.com/read/heathcliff/11/26/425797", page.prev_url
  end

  def test_missing_image_raises
    html = %(<meta property="og:title" content="Heathcliff for Nov 09, 2026, by X" />)
    err = assert_raises(Heathgets::Error) { Heathgets::Fetcher.parse(html, "https://example.test/") }
    assert_match(/og:image/, err.message)
  end

  def test_missing_prev_is_nil
    html = <<~HTML
      <meta property="og:title" content="Heathcliff for Jan 02, 2026, by X" />
      <meta property="og:image" content="/img/a.jpg" />
    HTML
    page = Heathgets::Fetcher.parse(html, "https://www.creators.com/read/heathcliff")
    assert_nil page.prev_url
    assert_equal Date.new(2026, 1, 2), page.date
    assert_equal "https://www.creators.com/img/a.jpg", page.image_url
  end
end
