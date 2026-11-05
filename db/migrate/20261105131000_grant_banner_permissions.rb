class GrantBannerPermissions < ActiveRecord::Migration[8.1]
  def up
    admin = Role.find_by(key: "admin")
    return unless admin

    %w[read create update destroy].each do |action|
      Permission.find_or_create_by!(role: admin, resource: "banners", action: action)
    end
  end

  def down
    admin = Role.find_by(key: "admin")
    return unless admin

    Permission.where(role: admin, resource: "banners").delete_all
  end
end
