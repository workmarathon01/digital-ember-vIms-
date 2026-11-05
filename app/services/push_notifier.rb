# High-level push API used by the rest of the application.
#
#   PushNotifier.deliver_to_user(user, title: "Visitor arrived", body: "Ravi is at the gate.")
#   PushNotifier.deliver_to_user(user, title: "...", uuid: "device-uuid")
#   PushNotifier.deliver_to_token(token, title: "...", async: false)
#
# Delivery is asynchronous by default through Solid Queue. Pass `async: false`
# only for diagnostics or a test-notification endpoint.
class PushNotifier
  PRIORITIES = %w[high normal].freeze
  MAX_TTL = 2_419_200 # 4 weeks: FCM's maximum message lifetime.

  class << self
    def deliver_to_user(user, title: nil, body: nil, data: {}, uuid: nil, async: true, **options)
      raise ArgumentError, "user is required" if user.blank?

      records = user.push_tokens.enabled
      records = records.where(uuid: uuid.to_s.strip) if uuid.present?
      deliver(records, title: title, body: body, data: data, async: async, **options)
    end

    def deliver_to_token(push_token, title: nil, body: nil, data: {}, async: true, **options)
      raise ArgumentError, "push_token is required" if push_token.blank?

      deliver([ push_token ], title: title, body: body, data: data, async: async, **options)
    end

    def deliver(records, title: nil, body: nil, data: {}, async: true, **options)
      records = Array(records).select { |record| record.is_a?(PushToken) && record.enabled? }
      return [] if records.empty?

      payload = build_payload(title: title, body: body, data: data, **options)

      if async
        PushNotificationJob.perform_later(
          records.map { |record| { "id" => record.id, "user_id" => record.user_id } },
          payload
        )
      else
        PushDelivery.call(records: records, payload: payload)
      end
    end

    # Builds a platform-aware FCM v1 message. Kept public so it can be unit
    # tested and inspected without making a network call.
    def build_payload(title: nil, body: nil, data: {}, image_url: nil, deep_link: nil, badge: nil,
                      sound: "default", channel_id: nil, icon: nil, color: nil, click_action: nil,
                      priority: "high", collapse_key: nil, ttl: nil, analytics_label: nil,
                      silent: false, content_available: false, android: {}, apns: {}, webpush: {},
                      fcm_options: {})
      priority = priority.to_s.downcase
      priority = "high" unless PRIORITIES.include?(priority)
      ttl = normalize_ttl(ttl)
      notification = build_notification(title, body, image_url)
      normalized_data = normalize_data(data)

      if deep_link.present? && !normalized_data.key?("link")
        normalized_data["link"] = deep_link.to_s
      end

      payload = {}
      payload["notification"] = notification if notification.present? && !silent
      payload["data"] = normalized_data if normalized_data.present?

      payload["android"] = build_android(
        priority: priority,
        ttl: ttl,
        collapse_key: collapse_key,
        silent: silent,
        notification: notification,
        channel_id: channel_id,
        sound: sound,
        icon: icon,
        color: color,
        image_url: image_url,
        click_action: click_action
      )

      payload["apns"] = build_apns(
        priority: priority,
        ttl: ttl,
        collapse_key: collapse_key,
        silent: silent,
        content_available: content_available,
        notification: notification,
        sound: sound,
        badge: badge,
        image_url: image_url
      )

      payload["webpush"] = build_webpush(
        priority: priority,
        ttl: ttl,
        notification: notification,
        data: normalized_data,
        deep_link: deep_link,
        icon: icon,
        image_url: image_url,
        collapse_key: collapse_key
      )

      if analytics_label.present?
        payload["fcm_options"] = { "analytics_label" => analytics_label.to_s }
      end

      overrides = {
        "android" => android || {},
        "apns" => apns || {},
        "webpush" => webpush || {},
        "fcm_options" => fcm_options || {}
      }.deep_stringify_keys
      payload = payload.deep_merge(overrides)

      compact_payload(payload)
    end

    private

    def build_notification(title, body, image_url)
      title = title.to_s.presence
      body = body.to_s.presence
      return if title.blank? && body.blank?

      {
        "title" => title,
        "body" => body,
        "image" => image_url.to_s.presence
      }.compact
    end

    def build_android(priority:, ttl:, collapse_key:, silent:, notification:, channel_id:, sound:,
                      icon:, color:, image_url:, click_action:)
      android = { "priority" => priority }
      android["ttl"] = "#{ttl}s" if ttl
      android["collapse_key"] = collapse_key.to_s if collapse_key.present?

      if notification.present? && !silent
        android_notification = {
          "channel_id" => channel_id.to_s.presence,
          "sound" => sound.presence,
          "icon" => icon.to_s.presence,
          "color" => color.to_s.presence,
          "image" => image_url.to_s.presence,
          "click_action" => click_action.to_s.presence
        }.compact
        android["notification"] = android_notification if android_notification.present?
      end

      android
    end

    def build_apns(priority:, ttl:, collapse_key:, silent:, content_available:, notification:,
                   sound:, badge:, image_url:)
      background = silent || notification.blank?

      headers = {
        "apns-priority" => priority == "high" ? "10" : "5",
        "apns-push-type" => background ? "background" : "alert"
      }
      headers["apns-expiration"] = (Time.current.to_i + ttl).to_s if ttl
      headers["apns-collapse-id"] = collapse_key.to_s[0, 64] if collapse_key.present?

      aps = {}
      aps["sound"] = sound.to_s if sound.present? && !background
      aps["badge"] = badge.to_i if badge.present?
      aps["content-available"] = 1 if background || content_available
      aps["mutable-content"] = 1 if image_url.present?

      { "headers" => headers, "payload" => { "aps" => aps } }
    end

    def build_webpush(priority:, ttl:, notification:, data:, deep_link:, icon:, image_url:, collapse_key:)
      webpush_headers = { "Urgency" => priority == "high" ? "high" : "normal" }
      webpush_headers["TTL"] = ttl.to_s if ttl
      webpush = { "headers" => webpush_headers }

      if notification.present?
        webpush["notification"] = {
          "title" => notification["title"],
          "body" => notification["body"],
          "icon" => icon.to_s.presence,
          "image" => image_url.to_s.presence,
          "badge" => icon.to_s.presence,
          "tag" => collapse_key.to_s.presence,
          "data" => data.presence
        }.compact
      end

      # Web push requires an HTTPS link. Custom app schemes stay in `data.link`.
      if deep_link.present? && deep_link.to_s.match?(%r{\Ahttps://}i)
        webpush["fcm_options"] = { "link" => deep_link.to_s }
      end

      webpush
    end

    def normalize_data(data)
      data = {} if data.nil?
      unless data.respond_to?(:each_pair)
        raise ArgumentError, "data must be a Hash"
      end

      data.each_pair.with_object({}) do |(key, value), result|
        key = key.to_s
        next if key.blank?

        result[key] = data_value(value)
      end
    end

    # FCM data payload values must be strings. Hashes/arrays are JSON encoded so
    # callers can pass structured context without thinking about the transport.
    def data_value(value)
      case value
      when Hash, Array then value.to_json
      when nil then ""
      when true then "true"
      when false then "false"
      else value.to_s
      end
    end

    def normalize_ttl(ttl)
      return if ttl.blank?

      value = ttl.to_i
      return if value <= 0

      [ value, MAX_TTL ].min
    end

    def compact_payload(value)
      case value
      when Hash
        value.each_with_object({}) do |(key, child), result|
          compacted = compact_payload(child)
          next if compacted.nil?
          next if compacted.respond_to?(:empty?) && compacted.empty?

          result[key] = compacted
        end
      else
        value
      end
    end
  end
end
