require "test_helper"

class StaffTest < ActiveSupport::TestCase
  test "generates staff id and token digest" do
    staff = Staff.create!(firstname: "Staff", lastname: "Member", mobile_no: "9876543210", site_id: 1)

    assert_match(/\ASTF[A-F0-9]{6}\z/, staff.staff_id)
    assert_predicate staff.qr_token_digest, :present?
    assert_equal "Pending", staff.status_type
  end

  test "mobile number is unique per site" do
    Staff.create!(firstname: "One", lastname: "Staff", mobile_no: "9876543210", site_id: 1)
    duplicate = Staff.new(firstname: "Two", lastname: "Staff", mobile_no: "9876543210", site_id: 1)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:mobile_no], "has already been taken"
  end
end
