require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "requires a strong password" do
    user = User.new(firstname: "Test", lastname: "User", email: "test@example.test", password: "short")

    assert_not user.valid?
    assert_includes user.errors[:password], "is too short (minimum is 12 characters)"
  end

  test "normalizes email and mobile" do
    user = User.create!(
      firstname: "Test",
      lastname: "User",
      email: " TEST@Example.TEST ",
      mobile: "+91 98765 43210",
      password: "StrongPass!2026"
    )

    assert_equal "test@example.test", user.email
    assert_equal "919876543210", user.mobile
  end

  test "stores and verifies otp by digest" do
    user = User.create!(
      firstname: "OTP",
      lastname: "User",
      email: "otp@example.test",
      password: "StrongPass!2026"
    )

    raw_otp = user.generate_otp!

    assert_not_equal raw_otp, user.reload.otp_digest
    assert user.verify_otp(raw_otp)
    assert_nil user.reload.otp_digest
  end
end
