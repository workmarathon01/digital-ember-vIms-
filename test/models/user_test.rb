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

  test "accepts an image profile photo and rejects other file types" do
    user = User.create!(
      firstname: "Photo",
      lastname: "User",
      email: "photo@example.test",
      password: "StrongPass!2026"
    )

    user.profile_image.attach(
      io: StringIO.new(File.binread(Rails.root.join("test/fixtures/files/profile.png"))),
      filename: "profile.png",
      content_type: "image/png"
    )
    assert user.valid?

    invalid = User.create!(
      firstname: "Text",
      lastname: "User",
      email: "text@example.test",
      password: "StrongPass!2026"
    )
    invalid.profile_image.attach(
      io: StringIO.new("not an image"),
      filename: "note.txt",
      content_type: "text/plain"
    )

    assert_not invalid.valid?
    assert_includes invalid.errors[:profile_image], "must be a JPEG, PNG or WebP image"
  end

  test "normalizes user type and assigns the matching role" do
    role = Role.find_or_create_by!(key: "gate_security") do |record|
      record.name = "Gate Security"
      record.power_level = 50
      record.is_system = true
    end

    user = User.create!(
      firstname: "Gate",
      lastname: "User",
      email: "gate-type@example.test",
      password: "StrongPass!2026",
      user_type: "Gate Security"
    )

    assert_equal "gate_security", user.user_type
    assert_equal role, user.role
  end

  test "employee registration type does not receive a role before approval" do
    user = User.create!(
      firstname: "Pending",
      lastname: "Employee",
      email: "pending-type@example.test",
      password: "StrongPass!2026",
      user_type: "employee"
    )

    assert_equal "employee", user.user_type
    assert_nil user.role
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
