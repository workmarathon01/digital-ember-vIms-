require "test_helper"

class BannerTest < ActiveSupport::TestCase
  def setup
    @site = Site.create!(name: "Banner Campus", code: "BNR#{SecureRandom.hex(3).upcase}")
  end

  test "requires a title and a site" do
    banner = Banner.new

    assert_not banner.valid?
    assert_includes banner.errors[:title], "can't be blank"
    assert_includes banner.errors[:site], "must exist"
  end

  test "normalizes title and external urls" do
    banner = Banner.create!(
      site: @site,
      title: "  Annual   Day  ",
      external_urls: [
        " https://example.com/a.pdf ",
        "https://example.com/a.pdf",
        "",
        "https://example.com/b.jpg"
      ]
    )

    assert_equal "Annual Day", banner.title
    assert_equal [ "https://example.com/a.pdf", "https://example.com/b.jpg" ], banner.external_urls
  end

  test "accepts newline separated external urls from the html form" do
    banner = Banner.create!(
      site: @site,
      title: "Notices",
      external_urls: "https://example.com/one.pdf\n\nhttps://example.com/two.pdf"
    )

    assert_equal [ "https://example.com/one.pdf", "https://example.com/two.pdf" ], banner.external_urls
  end

  test "rejects non http external urls" do
    banner = Banner.new(
      site: @site,
      title: "Unsafe",
      external_urls: [ "javascript:alert(1)", "ftp://example.com/file", "https://example.com/ok" ]
    )

    assert_not banner.valid?
    assert_equal 2, banner.errors[:external_urls].size
  end

  test "limits the number of attachments" do
    banner = Banner.new(
      site: @site,
      title: "Too many",
      external_urls: 11.times.map { |index| "https://example.com/#{index}.pdf" }
    )

    assert_not banner.valid?
    assert_includes banner.errors[:external_urls].join, "cannot have more than 10 URLs"
  end

  test "accepts image and pdf uploads" do
    banner = Banner.new(site: @site, title: "Uploads")
    banner.attachments.attach(
      io: File.open(Rails.root.join("test/fixtures/files/profile.png")),
      filename: "profile.png",
      content_type: "image/png"
    )

    assert banner.valid?
    assert_equal [ "profile.png" ], banner.image_attachments.map { |attachment| attachment.blob.filename.to_s }
  end

  test "rejects disallowed upload types" do
    banner = Banner.new(site: @site, title: "Unsafe upload")
    banner.attachments.attach(
      io: StringIO.new("not allowed"),
      filename: "notes.txt",
      content_type: "text/plain"
    )

    assert_not banner.valid?
    assert_includes banner.errors[:attachments].join, "must be an image"
  end

  test "active and ordered scopes" do
    inactive = Banner.create!(site: @site, title: "Inactive", active: false, sort_order: 1)
    second = Banner.create!(site: @site, title: "Second", sort_order: 2)
    first = Banner.create!(site: @site, title: "First", sort_order: 1)

    assert_equal [ first, second ], @site.banners.active.ordered.to_a
    assert_not_includes @site.banners.active.to_a, inactive
  end

  test "destroying a site removes its banners" do
    Banner.create!(site: @site, title: "Temporary")

    assert_difference("Banner.count", -1) { @site.destroy! }
  end
end
