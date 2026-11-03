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

    # Every model that stores a `site_id` is automatically limited to the
    # sites the user is attached to. Catalogs without a site (features, roles)
    # stay global.
    def resolve
      return scope.all unless site_restricted?
      return scope.all unless model.column_names.include?("site_id")

      scope.where(site_id: user.accessible_site_ids)
    end

    private

    def model
      scope.is_a?(Class) ? scope : scope.klass
    end

    def site_restricted?
      user.present? && user.site_restricted?
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
