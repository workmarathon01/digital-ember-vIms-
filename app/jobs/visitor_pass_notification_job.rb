class VisitorPassNotificationJob < ApplicationJob
  queue_as :default

  def perform(visitor_id)
    visitor = Visitor.active.find_by(id: visitor_id)
    return if visitor.nil?

    VisitorPassNotifier.new(visitor).deliver
  end
end
