namespace :push_tokens do
  desc "Delete disabled push tokens older than 60 days"
  task prune: :environment do
    deleted = PushToken.prune!
    puts "Deleted #{deleted} disabled push token(s)."
  end
end
