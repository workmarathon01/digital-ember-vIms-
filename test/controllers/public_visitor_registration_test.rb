require "test_helper"

class PublicVisitorRegistrationTest < ActionDispatch::IntegrationTest
  def setup
    @site = Site.create!(name: "Public Campus", code: "PUBLIC")
    @building = @site.buildings.create!(name: "Reception Block")
    @floor = @building.floors.create!(name: "Ground Floor")
    @unit = @floor.units.create!(name: "Lobby")
  end

  test "lookup returns not registered for an unknown mobile number" do
    get public_visitor_lookup_path(format: :json), params: { contact_no: "99999 00000" }

    assert_response :success
    assert_equal false, response.parsed_body["registered"]
    assert_nil response.parsed_body["visitor"]
  end

  test "lookup pre-fills the latest visitor for a known mobile number" do
    visitor = Visitor.create!(name: "Anita Rao", contact_no: "98765 43210", purpose: "Meeting")

    get public_visitor_lookup_path(format: :json), params: { contact_no: "9876543210" }

    assert_response :success
    body = response.parsed_body
    assert_equal true, body["registered"]
    assert_equal visitor.id, body.dig("visitor", "id")
    assert_equal "Anita Rao", body.dig("visitor", "name")
    assert_equal "9876543210", body.dig("visitor", "contact_no")
  end

  test "lookup rejects an invalid mobile number" do
    get public_visitor_lookup_path(format: :json), params: { contact_no: "123" }

    assert_response :unprocessable_entity
    assert_equal "invalid_contact_no", response.parsed_body.dig("error", "code")
  end

  test "a visitor can self-register without a token and receives a QR token" do
    assert_difference("Visitor.count", 1) do
      post public_visitors_path(format: :json), params: {
        visitor: {
          name: "Self Registered",
          contact_no: "98765 12345",
          purpose: "Meeting",
          site_id: @site.id,
          unit_id: @unit.id,
          expected_date: Date.current.iso8601,
          vehicle_number: "MH 01 AB 1234"
        }
      }
    end

    assert_response :created
    body = response.parsed_body
    visitor = Visitor.order(:created_at).last

    assert_equal "Self Registered", body.dig("visitor", "name")
    assert body.dig("visitor", "pass_code").present?
    assert body.dig("visitor", "qr_token").present?
    assert_equal @site.id, body.dig("visitor", "site_id")
    assert_equal @unit.id, body.dig("visitor", "unit_id")
    assert_nil visitor.created_by
    assert visitor.status
    assert visitor.qr_token_digest.present?
    assert_not_equal body.dig("visitor", "qr_token"), visitor.qr_token_digest
  end

  test "self-registration validates the mobile number" do
    post public_visitors_path(format: :json), params: {
      visitor: { name: "No Number", contact_no: "123" }
    }

    assert_response :unprocessable_entity
    assert_equal "validation_failed", response.parsed_body.dig("error", "code")
  end

  test "self-registration returns a public pass URL" do
    post public_visitors_path(format: :json), params: {
      visitor: { name: "Linked Guest", contact_no: "9876500099", purpose: "Meeting" }
    }

    assert_response :created
    body = response.parsed_body
    pass_url = body.dig("visitor", "pass_url")

    assert_match %r{\Ahttps://amplify-automation\.com/access/\?t=}, pass_url
    assert_equal "Linked Guest", body.dig("visitor", "name")
  end

  test "public pass endpoint returns pass details for a signed token" do
    post public_visitors_path(format: :json), params: {
      visitor: { name: "Pass Viewer", contact_no: "9876500088", purpose: "Interview" }
    }
    assert_response :created
    created = response.parsed_body["visitor"]
    token = created["qr_token"]

    get public_visitor_pass_path(format: :json), params: { token: token }

    assert_response :success
    body = response.parsed_body
    assert_equal true, body["found"]
    assert_equal false, body["already_checked_in"]
    assert_equal created["id"], body.dig("visitor", "id")
    assert_equal "Pass Viewer", body.dig("visitor", "name")
    assert_equal created["pass_code"], body.dig("visitor", "pass_code")
    assert_equal created["pass_url"], body.dig("visitor", "pass_url")
    assert body.dig("visitor", "created_at").present?
    assert body.dig("visitor", "start_pass").present?
    assert body.dig("visitor", "end_pass").present?
  end

  test "public pass endpoint rejects a bare pass code" do
    visitor = Visitor.create!(name: "Code Only Guest", contact_no: "9876500077")

    get public_visitor_pass_path(format: :json), params: { token: visitor.pass_code }

    assert_response :not_found
    assert_equal "pass_not_found", response.parsed_body.dig("error", "code")
  end

  test "public pass endpoint rejects an unknown token" do
    get public_visitor_pass_path(format: :json), params: { token: "not-a-signed-token" }

    assert_response :not_found
    assert_equal "pass_not_found", response.parsed_body.dig("error", "code")
  end

  test "public pass endpoint requires a token" do
    get public_visitor_pass_path(format: :json)

    assert_response :not_found
    assert_equal "pass_not_found", response.parsed_body.dig("error", "code")
  end

  test "hosts endpoint returns only the residents linked to the selected unit" do
    host = User.create!(
      firstname: "Hari", lastname: "Host", email: "hari-host@example.test",
      password: "StrongPass!2026", unit: @unit
    )
    other_unit = @floor.units.create!(name: "Other Unit")
    other_host = User.create!(
      firstname: "Other", lastname: "Host", email: "other-host@example.test",
      password: "StrongPass!2026", unit: other_unit
    )

    get public_hosts_path(format: :json), params: { unit_id: @unit.id }

    assert_response :success
    hosts = response.parsed_body["hosts"]
    assert_equal [ host.id ], hosts.map { |item| item["id"] }
    assert_equal host.full_name, hosts.first["full_name"]
    assert_not_includes hosts.map { |item| item["id"] }, other_host.id
  end

  test "self-registration accepts a host and profile photo" do
    host = User.create!(
      firstname: "Meera", lastname: "Host", email: "meera-host@example.test",
      password: "StrongPass!2026", unit: @unit
    )

    post public_visitors_path(format: :json), params: {
      visitor: {
        name: "Photo Guest",
        contact_no: "98765 22222",
        purpose: "Meeting",
        site_id: @site.id,
        unit_id: @unit.id,
        vhost_id: host.id,
        profile_image: fixture_file_upload("profile.png", "image/png")
      }
    }

    assert_response :created
    body = response.parsed_body
    visitor = Visitor.find(body.dig("visitor", "id"))

    assert_equal host.id, body.dig("visitor", "vhost_id")
    assert_equal host.full_name, body.dig("visitor", "host_name")
    assert body.dig("visitor", "profile_image_url").present?
    assert visitor.profile_image.attached?
  end

  test "a returning visitor keeps their previous profile photo" do
    post public_visitors_path(format: :json), params: {
      visitor: {
        name: "Returning Photo",
        contact_no: "98765 33333",
        profile_image: fixture_file_upload("profile.png", "image/png")
      }
    }
    assert_response :created
    first_visitor = Visitor.find(response.parsed_body.dig("visitor", "id"))
    assert first_visitor.profile_image.attached?

    post public_visitors_path(format: :json), params: {
      visitor: { name: "Returning Photo", contact_no: "98765 33333" }
    }

    assert_response :created
    second_visitor = Visitor.find(response.parsed_body.dig("visitor", "id"))
    assert second_visitor.profile_image.attached?
    assert response.parsed_body.dig("visitor", "profile_image_url").present?
  end

  test "lookup does not expose a previous visitor photo" do
    post public_visitors_path(format: :json), params: {
      visitor: {
        name: "Private Photo",
        contact_no: "98765 55555",
        profile_image: fixture_file_upload("profile.png", "image/png")
      }
    }
    assert_response :created

    get public_visitor_lookup_path(format: :json), params: { contact_no: "9876555555" }

    assert_response :success
    assert_nil response.parsed_body.dig("visitor", "profile_image_url")
  end

  test "self-registration rejects a host from another unit" do
    other_unit = @floor.units.create!(name: "Different Unit")
    other_host = User.create!(
      firstname: "Different", lastname: "Host", email: "different-host@example.test",
      password: "StrongPass!2026", unit: other_unit
    )

    post public_visitors_path(format: :json), params: {
      visitor: {
        name: "Wrong Host Guest",
        contact_no: "98765 44444",
        unit_id: @unit.id,
        vhost_id: other_host.id
      }
    }

    assert_response :unprocessable_entity
    assert_equal "validation_failed", response.parsed_body.dig("error", "code")
    assert_match(/selected unit/, response.parsed_body.dig("error", "message"))
  end

  test "a QR token can be verified and checked in only once" do
    post public_visitors_path(format: :json), params: {
      visitor: { name: "QR Guest", contact_no: "9876500001" }
    }
    token = response.parsed_body.dig("visitor", "qr_token")
    pass_code = response.parsed_body.dig("visitor", "pass_code")

    get public_visitor_verify_path(format: :json), params: { code: token }

    assert_response :success
    assert_equal true, response.parsed_body["found"]
    assert_equal false, response.parsed_body["already_checked_in"]
    assert_equal "QR Guest", response.parsed_body.dig("visitor", "name")

    get public_visitor_verify_path(format: :json),
        params: { code: "https://visitor.example.test/scan?t=#{CGI.escape(token)}" }

    assert_response :success
    assert_equal true, response.parsed_body["found"]

    post public_visitor_check_in_path(format: :json), params: { code: token }

    assert_response :success
    assert_equal false, response.parsed_body["already_checked_in"]
    assert_equal true, response.parsed_body.dig("visitor", "checked_in")

    post public_visitor_check_in_path(format: :json), params: { code: pass_code }

    assert_response :success
    assert_equal true, response.parsed_body["already_checked_in"]
    assert_equal true, response.parsed_body.dig("visitor", "checked_in")
  end

  test "lookup reports whether the latest active pass is checked in" do
    post public_visitors_path(format: :json), params: {
      visitor: { name: "Returning Guest", contact_no: "9876511111" }
    }
    token = response.parsed_body.dig("visitor", "qr_token")

    get public_visitor_lookup_path(format: :json), params: { contact_no: "9876511111" }
    assert_equal false, response.parsed_body["currently_checked_in"]

    post public_visitor_check_in_path(format: :json), params: { code: token }
    assert_response :success

    get public_visitor_lookup_path(format: :json), params: { contact_no: "9876511111" }
    assert_equal true, response.parsed_body["currently_checked_in"]

    Visitor.find_by_scan_code(token).mark_checked_out!

    get public_visitor_lookup_path(format: :json), params: { contact_no: "9876511111" }
    assert_equal false, response.parsed_body["currently_checked_in"]
  end

  test "unknown pass code cannot be verified or checked in" do
    get public_visitor_verify_path(format: :json), params: { code: "not-a-pass" }
    assert_response :not_found
    assert_equal "pass_not_found", response.parsed_body.dig("error", "code")

    post public_visitor_check_in_path(format: :json), params: { code: "not-a-pass" }
    assert_response :not_found
  end

  test "form options expose only public property labels" do
    get public_form_options_path(format: :json)

    assert_response :success
    assert_equal @site.id, response.parsed_body.dig("sites", 0, "id")
    assert_equal @unit.id, response.parsed_body.dig("units", 0, "id")
    assert_equal "Public Campus / Reception Block / Ground Floor / Lobby",
                 response.parsed_body.dig("units", 0, "location_label")
  end
end
