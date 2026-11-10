$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "heathgets"
require "minitest/autorun"
require "tmpdir"
require "stringio"

Heathgets.logger = Logger.new(StringIO.new)

FIXTURES = File.expand_path("fixtures", __dir__)

def fixture(name) = File.read(File.join(FIXTURES, name))

def jpeg(tag = "x")
  Heathgets::Fetcher::Image.new(bytes: "JPEG-#{tag}", content_type: "image/jpeg", extension: "jpg")
end
