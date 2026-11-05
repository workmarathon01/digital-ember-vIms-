require "test_helper"

class BannersTest < ActionDispatch::IntegrationTest
  PASSWORD = "StrongPass!2026".freeze

  def setup
    @site_a = Site.create!(name: "Alpha Campus", code: "ALPHA-BNR")
    @site_b = Site.create!(name: "Beta Campus", code: "BETA-BNR")

    @admin_role = Role.find_or_create_by!(key: "banner_admin") do |role|
      role.name = "Banner Admin"
      role.power_level = 80
    end
    grant_all_permissions(@admin_role)

    @admin = User.create!(
      firstname: "Banner",
      lastname: "Admin",
      email: "banner-admin@example.test",
      password: PASSWORD,
      role: @admin_role,
      current_site_id: @site_a.id
    )

    @super_admin_role = Role.find_or_create_by!(key: "super_admin") do |role|
      role.name = "Super Administrator"
      role.power_level = 100
      role.is_system = true
    end
    @super_admin = User.create!(
      firstname: "Super",
      lastname: "Admin",
      email: "banner-super-admin@example.test",
      password: PASSWORD,
      role: @super_admin_role
    )

    @limited_role = Role.find_or_create_by!(key: "banner_viewer") do |role|
      role.name = "Banner Viewer"
      role.power_level = 20
    end
    @limited_role.permissions.find_or_create_by!(resource: "visitors", action: "read")
    @viewer = User.create!(
      firstname: "Banner",
      lastname: "Viewer",
      email: "banner-viewer@example.test",
      password: PASSWORD,
      role: @limited_role,
      current_site_id: @site_a.id
    )

    @banner_a = Banner.create!(
      site: @site_a,
      title: "Alpha notice",
      description: "Alpha description",
      external_urls: [ "https://example.com/alpha.pdf" ]
    )
    @banner_b = Banner.create!(
      site: @site_b,
      title: "Beta notice",
      external_urls: [ "https://example.com/beta.pdf" ]
    )
  end

  def grant_all_permissions(role)
    Role::RESOURCES.each do |resource|
      resource[:actions].each do |action|
        role.permissions.find_or_create_by!(resource: resource[:key], action: action)
      end
    end
  end

  def headers_for(user)
    post session_path(format: :json), params: { email: user.email, password: PASSWORD }
    { "Authorization" => "Bearer #{response.parsed_body.fetch('access_token')}" }
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: PASSWORD }
  end

  test "index is scoped to the signed-in user's site" do
    get banners_path(format: :json), headers: headers_for(@admin)

    assert_response :success
    titles = response.parsed_body.fetch("data").map { |banner| banner.fetch("title") }
    assert_equal [ "Alpha notice" ], titles
  end

  test "super admin can select another site" do
    get banners_path(format: :json, site_id: @site_b.id), headers: headers_for(@super_admin)

    assert_response :success
    titles = response.parsed_body.fetch("data").map { |banner| banner.fetch("title") }
    assert_equal [ "Beta notice" ], titles
  end

  test "creates a banner with multiple external urls" do
    assert_difference("Banner.count", 1) do
      post banners_path(format: :json), headers: headers_for(@admin), params: {
        banner: {
          site_id: @site_a.id,
          title: "Fire drill",
          description: "Assembly point is the north lawn.",
          external_urls: [ "https://example.com/map.pdf", "https://example.com/guide.pdf" ],
          sort_order: 5
        }
      }
    end

    assert_response :created
    body = response.parsed_body
    assert_equal "Fire drill", body.fetch("title")
    assert_equal [ "https://example.com/map.pdf", "https://example.com/guide.pdf" ], body.fetch("external_urls")
    assert_equal @site_a.id, body.fetch("site_id")
  end

  test "creates a banner with uploaded files" do
    assert_difference("Banner.count", 1) do
      post banners_path(format: :json), headers: headers_for(@admin), params: {
        banner: {
          site_id: @site_a.id,
          title: "Uploaded images",
          attachments: [ fixture_file_upload("profile.png", "image/png") ]
        }
      }
    end

    assert_response :created
    banner = Banner.order(:created_at).last
    assert banner.attachments.attached?
    attachment = response.parsed_body.fetch("attachments").first
    assert_equal "profile.png", attachment.fetch("filename")
    assert_equal "image/png", attachment.fetch("content_type")
    assert attachment.fetch("image")
    assert attachment.fetch("url").present?
  end

  test "removes an uploaded file" do
    @banner_a.attachments.attach(
      io: File.open(Rails.root.join("test/fixtures/files/profile.png")),
      filename: "profile.png",
      content_type: "image/png"
    )
    attachment = @banner_a.attachments.first

    patch banner_path(@banner_a, format: :json), headers: headers_for(@admin), params: {
      banner: { remove_attachment_ids: [ attachment.id ] }
    }

    assert_response :success
    assert_empty response.parsed_body.fetch("attachments")
    assert_empty @banner_a.reload.attachments
  end

  test "rejects a banner with an invalid external URL" do
    assert_no_difference("Banner.count") do
      post banners_path(format: :json), headers: headers_for(@admin), params: {
        banner: {
          site_id: @site_a.id,
          title: "Unsafe link",
          external_urls: [ "javascript:alert(1)" ]
        }
      }
    end

    assert_response :unprocessable_entity
    assert_equal "validation_failed", response.parsed_body.dig("error", "code")
  end

  test "cannot open a banner from another site" do
    get banner_path(@banner_b, format: :json), headers: headers_for(@admin)

    assert_response :not_found
  end

  test "updates and deletes a banner" do
    headers = headers_for(@admin)

    patch banner_path(@banner_a, format: :json), headers: headers, params: {
      banner: { title: "Updated notice", external_urls: [ "https://example.com/updated.pdf" ] }
    }

    assert_response :success
    assert_equal "Updated notice", @banner_a.reload.title
    assert_equal [ "https://example.com/updated.pdf" ], @banner_a.external_urls

    assert_difference("Banner.count", -1) do
      delete banner_path(@banner_a, format: :json), headers: headers
    end

    assert_response :no_content
  end

  test "html form accepts multiple file uploads" do
    sign_in(@admin)

    get edit_banner_path(@banner_a)

    assert_response :success
    assert_select "input[type='file'][name='banner[attachments][]'][multiple]"
  end

  test "html show renders attachment links that open in a new tab" do
    @banner_a.attachments.attach(
      io: File.open(Rails.root.join("test/fixtures/files/profile.png")),
      filename: "profile.png",
      content_type: "image/png"
    )
    sign_in(@admin)

    get banner_path(@banner_a)

    assert_response :success
    assert_select "a[href='https://example.com/alpha.pdf'][target='_blank'][rel='noopener noreferrer']", text: "https://example.com/alpha.pdf"
    assert_select "a[target='_blank'][rel='noopener noreferrer']", text: "profile.png"
    assert_select "img[alt='profile.png']"
  end

  test "user without banner permission cannot manage banners" do
    sign_in(@viewer)

    get banners_path

    assert_redirected_to root_path

    get banners_path(format: :json), headers: headers_for(@viewer)
    assert_response :forbidden
  end

  test "dashboard shows active banners for the current site only" do
    Banner.create!(site: @site_a, title: "Hidden notice", active: false)
    Banner.create!(site: @site_b, title: "Other site notice")

    get root_path(format: :json), headers: headers_for(@admin)

    assert_response :success
    titles = response.parsed_body.fetch("banners").map { |banner| banner.fetch("title") }
    assert_equal [ "Alpha notice" ], titles
  end
end
