require "test_helper"

class FeatureEntitlementTest < ActiveSupport::TestCase
  def setup
    @site = Site.create!(name: "Feature Campus", code: "FEATURES")
    @other_site = Site.create!(name: "Other Campus", code: "OTHERFEAT")
    @visitor_feature = Feature.create!(name: "Visitor Management", category: "operations")
    @staff_feature = Feature.create!(name: "Staff Management", category: "operations")
    @report_feature = Feature.create!(name: "Reports", category: "reporting")
    @user = User.create!(firstname: "Feature", lastname: "User", email: "feature-user@example.test",
                         password: "StrongPass!2026", current_site: @site)
  end

  test "feature keys are normalized and unique" do
    feature = Feature.create!(name: "Gate Passes & OTP", category: "security")

    assert_equal "gate_passes_otp", feature.key
    assert_not Feature.new(name: "Another", key: "gate_passes_otp").valid?
    assert_not Feature.new(name: "Bad", key: "1invalid").valid?
    assert_not Feature.new(name: "Bad Category", category: "unknown").valid?
  end

  test "site sync replaces entitlements and clears orphaned user overrides" do
    @site.sync_features!([ @visitor_feature.id, @staff_feature.id ])
    @user.sync_feature_overrides!(@site, { @staff_feature.id => "revoked" })

    assert @site.feature_enabled?(@visitor_feature)
    assert @site.feature_enabled?("staff_management")
    assert_not @site.feature_enabled?(@report_feature)
    assert_not @user.feature_enabled?(@staff_feature)

    @site.sync_features!([ @visitor_feature.id ])

    assert @site.feature_enabled?(@visitor_feature)
    assert_not @site.feature_enabled?(@staff_feature)
    assert_equal 0, @user.user_features.where(feature: @staff_feature).count
  end

  test "users inherit site features and can revoke or restore them" do
    @site.sync_features!([ @visitor_feature.id, @staff_feature.id ])

    assert_equal %w[staff_management visitor_management], @user.feature_keys.sort

    @user.sync_feature_overrides!(@site, { @staff_feature.id => "revoked" })

    assert_not @user.feature_enabled?(@staff_feature)
    assert @user.feature_enabled?(@visitor_feature)
    assert_equal "revoked", @user.feature_override_state(@staff_feature, @site)

    @user.sync_feature_overrides!(@site, { @staff_feature.id => "inherit" })

    assert @user.feature_enabled?(@staff_feature)
    assert_equal "inherit", @user.feature_override_state(@staff_feature, @site)
  end

  test "feature access is scoped to the site" do
    @site.sync_features!([ @visitor_feature.id ])
    @other_site.sync_features!([ @report_feature.id ])

    assert_equal [ "visitor_management" ], @user.feature_keys(@site)
    assert_equal [ "reports" ], @user.feature_keys(@other_site)
  end

  test "a user cannot be granted a feature that the site has not enabled" do
    override = UserFeature.new(user: @user, site: @site, feature: @report_feature, enabled: true)

    assert_not override.valid?
    assert_match(/must be enabled for the site/i, override.errors[:feature].to_sentence)
  end

  test "features assigned to a site cannot be deleted" do
    @site.sync_features!([ @visitor_feature.id ])

    assert_not @visitor_feature.destroy
    assert_match(/disable this feature/i, @visitor_feature.errors.full_messages.to_sentence)
  end

  test "inactive features are excluded from site entitlements" do
    @site.sync_features!([ @visitor_feature.id ])
    @visitor_feature.update!(active: false)

    assert_not @site.feature_enabled?(@visitor_feature)
    assert_empty @user.feature_keys(@site)
  end
end
