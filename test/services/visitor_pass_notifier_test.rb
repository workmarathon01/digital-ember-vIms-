require "test_helper"

class VisitorPassNotifierTest < ActiveSupport::TestCase
  test "message contains the public pass URL and validity window" do
    visitor = Visitor.create!(
      name: "Notify Guest",
      contact_no: "9876543215",
      purpose: "Meeting"
    )

    message = VisitorPassNotifier.new(visitor).message

    assert_includes message, visitor.public_pass_url
    assert_includes message, visitor.pass_code
    assert_includes message, "Valid from"
    assert_includes message, "Do not share this link"
  end

  test "delivery is skipped when the visitor has no mobile number" do
    visitor = Visitor.new(name: "No Phone")

    assert_equal false, VisitorPassNotifier.new(visitor).deliver
  end
end
