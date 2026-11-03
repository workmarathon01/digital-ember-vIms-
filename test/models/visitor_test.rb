require "test_helper"

class VisitorTest < ActiveSupport::TestCase
  test "generates digested qr token on create" do
    visitor = Visitor.create!(name: "Guest", contact_no: "9876543210")

    assert_predicate visitor.qr_token_digest, :present?
    assert_predicate visitor.qr_generated_at, :present?
  end

  test "provides a scannable qr token for any existing visitor" do
    visitor = Visitor.create!(name: "Existing Guest", contact_no: "9876543211")

    token = visitor.reload.qr_token
    assert token.present?
    assert_equal visitor, Visitor.find_by_scan_code(token)

    # Tokens survive a fresh load, so a pass QR can be reprinted at any time.
    reloaded = Visitor.find(visitor.id)
    assert_equal token, reloaded.qr_token
    assert_equal visitor, Visitor.find_by_scan_code(reloaded.qr_token)
  end

  test "builds an absolute public pass URL from the signed token" do
    visitor = Visitor.create!(name: "Pass Link Guest", contact_no: "9876543212")

    url = visitor.public_pass_url
    assert_match %r{\Ahttps://amplify-automation\.com/access/\?t=}, url

    token = Rack::Utils.parse_query(URI.parse(url).query)["t"]
    assert_equal visitor, Visitor.find_by_public_token(token)
  end

  test "public pass token stays short enough for sms" do
    visitor = Visitor.create!(name: "Compact Guest", contact_no: "9876543216")

    token = visitor.reload.qr_token
    assert_match Visitor::COMPACT_TOKEN_PATTERN, token
    # id (base36) + "-" + 11-char signature, well under the old ~180-char token.
    assert_operator token.length, :<=, 16

    url = visitor.public_pass_url
    assert_operator url.length, :<=, 65
    assert_equal visitor, Visitor.find_by_public_token(token)
  end

  test "legacy long pass links keep working" do
    visitor = Visitor.create!(name: "Legacy Guest", contact_no: "9876543217")
    legacy = Visitor.qr_verifier.generate(
      { "visitor_id" => visitor.id, "pass_code" => visitor.pass_code },
      purpose: "visitor-pass"
    )

    assert_operator legacy.length, :>, 100
    assert_equal visitor, Visitor.find_by_public_token(legacy)
  end

  test "a tampered compact pass token is rejected" do
    visitor = Visitor.create!(name: "Tamper Guest", contact_no: "9876543218")
    id, signature = visitor.qr_token.split("-", 2)
    replacement = signature.start_with?("A") ? "B" : "A"
    tampered = "#{id}-#{replacement}#{signature[1..]}"

    assert_nil Visitor.find_by_public_token(tampered)
  end

  test "a bare pass code cannot open the public pass page" do
    visitor = Visitor.create!(name: "Guarded Guest", contact_no: "9876543213")

    assert_nil Visitor.find_by_public_token(visitor.pass_code)
  end

  test "new passes are active by default" do
    visitor = Visitor.create!(name: "Active Guest", contact_no: "9876543214")

    assert_equal true, visitor.status
    assert_predicate visitor, :pass_active?
  end

  test "verifies otp and marks visitor checked in" do
    visitor = Visitor.create!(name: "Guest", contact_no: "9876543210")
    raw_otp = visitor.generate_otp!

    assert visitor.verify_otp(raw_otp)
    visitor.mark_checked_in!

    assert_equal "IN", visitor.visitor_in_out
    assert_predicate visitor, :verified?
  end
end
