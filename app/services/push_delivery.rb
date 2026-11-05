class PushDelivery
  # Sends one payload to a set of PushToken rows and performs the token hygiene
  # that FCM expects: permanently invalid tokens are disabled; transient
  # failures are recorded but left enabled for a later attempt.
  def self.call(records:, payload:)
    records = Array(records).select { |record| record.is_a?(PushToken) && record.enabled? }
    return [] if records.empty?

    records_by_token = records.index_by(&:token)
    results = Fcm::Client.new.deliver_each(tokens: records_by_token.keys, payload: payload)

    invalid_tokens = []
    failed_results = []

    results.each do |result|
      if result.success?
        next
      elsif result.invalid_token?
        invalid_tokens << result.token
      else
        failed_results << result
      end
    end

    disable_invalid_tokens(invalid_tokens)
    record_failures(failed_results, records_by_token)

    Rails.logger.info(
      "[PushDelivery] total=#{results.size} sent=#{results.count(&:success?)} " \
      "invalid=#{invalid_tokens.size} failed=#{failed_results.size}"
    )

    results
  end

  def self.disable_invalid_tokens(tokens)
    return if tokens.empty?

    PushToken.where(token: tokens).update_all(
      enabled: false,
      disabled_at: Time.current,
      last_error: "invalid_token",
      updated_at: Time.current
    )
  end
  private_class_method :disable_invalid_tokens

  def self.record_failures(results, records_by_token)
    results.each do |result|
      record = records_by_token[result.token]
      next if record.nil?

      record.update_columns(
        failed_count: record.failed_count + 1,
        last_error: result.error_code.presence || "delivery_failed",
        updated_at: Time.current
      )
    end
  end
  private_class_method :record_failures
end
