class DashboardPolicy
  attr_reader :user

  def initialize(user, _record)
    @user = user
  end

  def view?
    user.present? && (
      user.can?(:visitors, :read) ||
      user.can?(:staffs, :read) ||
      user.can?(:users, :read) ||
      user.can?(:roles, :read)
    )
  end
end
