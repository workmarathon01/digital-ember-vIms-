require "test_helper"

class FeatureAccessTest < ActionDispatch::IntegrationTest
  PASSWORD = "StrongPass!2026".freeze

  def setup
    @admin_role = Role.find_or_create_by!(key: "admin") do |role|
      role.name = "System Administrator"
      role.power_level = 100
      role.is_system = true
    end

    @admin = User.create!(
      firstname: "Feature",
      lastname: "Admin",
      email: "feature-admin@example.test",
      password: PASSWORD,
      role: @admin_role
    )

    @site = Site.create!(name: "Access Campus", code: "ACCESS")
    @admin.update!(current_site: @site)
    @feature = Feature.create!(name: "Visitor Management", category: "operations")
    @other_feature = Feature.create!(name: "Reports", category: "reporting")
    @site.sync_features!([ @feature.id ])
  end

  def sign_in_json(user = @admin)
    post session_path(format: :json), params: { email: user.email, password: PASSWORD }
    response.parsed_body.fetch("access_token")
  end

  def auth_headers(user = @admin)
    { "Authorization" => "Bearer #{sign_in_json(user)}" }
  end

  test "json login includes the user's effective feature keys" do
    post session_path(format: :json), params: { email: @admin.email, password: PASSWORD }

    assert_response :success
    assert_equal true, response.parsed_body.dig("user", "features_configured")
    assert_includes response.parsed_body.dig("user", "feature_keys"), "visitor_management"
    assert_not_includes response.parsed_body.dig("user", "feature_keys"), "reports"
  end

  test "login marks features as unconfigured when the catalog is empty" do
    Feature.update_all(active: false)

    post session_path(format: :json), params: { email: @admin.email, password: PASSWORD }

    assert_response :success
    assert_equal false, response.parsed_body.dig("user", "features_configured")
    assert_empty response.parsed_body.dig("user", "feature_keys")
  end

  test "standard feature templates are available to feature readers" do
    get feature_templates_path(format: :json), headers: auth_headers

    assert_response :success
    assert response.parsed_body.any? { |template| template["key"] == "property_management" }
    assert response.parsed_body.any? { |template| template["key"] == "visitor_management" }
  end

  test "admin can create update and delete a feature" do
    headers = auth_headers

    post features_path(format: :json),
         params: { feature: { name: "Kiosk Mode", category: "security", description: "Self service" } },
         headers: headers

    assert_response :created
    feature = Feature.find_by!(key: "kiosk_mode")

    patch feature_path(feature, format: :json),
          params: { feature: { description: "Updated description" } },
          headers: headers

    assert_response :success
    assert_equal "Updated description", feature.reload.description

    delete feature_path(feature, format: :json), headers: headers

    assert_response :no_content
    assert_not Feature.exists?(feature.id)
  end

  test "assigned features cannot be deleted through the API" do
    delete feature_path(@feature, format: :json), headers: auth_headers

    assert_response :unprocessable_entity
    assert_equal "delete_blocked", response.parsed_body.dig("error", "code")
    assert Feature.exists?(@feature.id)
  end

  test "site feature access can be read and replaced over JSON" do
    headers = auth_headers

    get site_features_path(@site, format: :json), headers: headers

    assert_response :success
    body = response.parsed_body
    assert_equal [ @feature.id ], body.fetch("enabled_feature_ids")
    assert body.fetch("features").any? { |item| item["key"] == "visitor_management" && item["enabled"] }

    patch site_features_path(@site, format: :json),
          params: { feature_ids: [ @other_feature.id ] },
          headers: headers

    assert_response :success
    assert @site.reload.feature_enabled?(@other_feature)
    assert_not @site.feature_enabled?(@feature)
  end

  test "updating a site without feature parameters preserves its entitlements" do
    patch site_path(@site, format: :json),
          params: { site: { name: "Renamed Access Campus" } },
          headers: auth_headers

    assert_response :success
    assert_equal "Renamed Access Campus", @site.reload.name
    assert @site.feature_enabled?(@feature)
  end

  test "new sites inherit catalog defaults when features are not supplied" do
    default_feature = Feature.create!(name: "Default Capability", category: "platform", default_enabled: true)

    post sites_path(format: :json),
         params: { site: { name: "Default Feature Site", code: "DEFAULTFEAT" } },
         headers: auth_headers

    assert_response :created
    site = Site.find_by!(code: "DEFAULTFEAT")
    assert site.feature_enabled?(default_feature)
    assert_not site.feature_enabled?(@other_feature)
  end

  test "user feature overrides can be read and updated over JSON" do
    headers = auth_headers

    get user_features_path(@admin, format: :json), params: { site_id: @site.id }, headers: headers

    assert_response :success
    assert_equal [ @feature.id ], response.parsed_body.fetch("effective_feature_ids")

    patch user_features_path(@admin, format: :json),
          params: { site_id: @site.id, overrides: { @feature.id.to_s => "revoked" } },
          headers: headers

    assert_response :success
    assert_not @admin.reload.feature_enabled?(@feature, @site)
    assert_equal "revoked", response.parsed_body.fetch("features").first.fetch("override")
  end

  test "a user without feature permissions is forbidden" do
    viewer_role = Role.create!(name: "Viewer", key: "feature_viewer", power_level: 5)
    viewer = User.create!(
      firstname: "Feature",
      lastname: "Viewer",
      email: "feature-viewer@example.test",
      password: PASSWORD,
      role: viewer_role
    )

    get site_features_path(@site, format: :json), headers: auth_headers(viewer)

    assert_response :forbidden
  end
end
