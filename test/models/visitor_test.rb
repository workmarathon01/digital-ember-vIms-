require "test_helper"

class VisitorTest < ActiveSupport::TestCase
  test "generates digested qr token on create" do
    visitor = Visitor.create!(name: "Guest", contact_no: "9876543210")

    assert_predicate visitor.qr_token_digest, :present?
    assert_predicate visitor.qr_generated_at, :present?
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
