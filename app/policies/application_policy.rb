class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?   = permission?(:read)
  def show?    = permission?(:read)
  def create?  = permission?(:create)
  def new?     = create?
  def update?  = permission?(:update)
  def edit?    = update?
  def destroy? = permission?(:destroy)

  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      scope.all
    end
  end

  private

  def permission?(action)
    user.present? && user.can?(resource_key, action)
  end

  def resource_key
    klass = record.is_a?(Class) ? record : record.class
    klass.name.underscore.pluralize
  end
end
