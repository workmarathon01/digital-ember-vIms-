class Banner < ApplicationRecord
  include Auditable

  MAX_ATTACHMENTS = 10
  MAX_UPLOAD_BYTES = 10.megabytes
  ALLOWED_UPLOAD_TYPES = %w[
    image/jpeg
    image/png
    image/webp
    image/gif
    application/pdf
  ].freeze

  has_many_attached :attachments

  belongs_to :site

  normalizes :title, with: ->(title) { title.to_s.strip.squish }

  before_validation :normalize_external_urls

  validates :title, presence: true, length: { maximum: 160 }
  validates :description, length: { maximum: 2_000 }, allow_blank: true
  validates :sort_order, numericality: { only_integer: true }
  validate :external_urls_are_valid
  validate :acceptable_uploads

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:sort_order, created_at: :asc) }

  # Accepts either the JSON array used by the API or a newline-separated
  # string used by the HTML form. Blank, duplicate and non-http(s) entries are
  # removed or rejected before the row is saved.
  def external_urls=(value)
    self[:external_urls] = normalize_urls(value)
  end

  def primary_external_url
    Array(external_urls).first
  end

  def image_attachments
    attachments.select { |attachment| attachment.blob.image? }
  end

  private

  def normalize_external_urls
    self[:external_urls] = normalize_urls(self[:external_urls])
  end

  def normalize_urls(value)
    urls =
      case value
      when String then value.split(/\r?\n/)
      when Array then value
      else []
      end

    urls.map { |url| url.to_s.strip }
        .reject(&:blank?)
        .uniq
  end

  def external_urls_are_valid
    urls = Array(external_urls)

    if urls.length > MAX_ATTACHMENTS
      errors.add(:external_urls, "cannot have more than #{MAX_ATTACHMENTS} URLs")
    end

    urls.each do |url|
      begin
        uri = URI.parse(url)
      rescue URI::InvalidURIError
        errors.add(:external_urls, "#{url.inspect} is not a valid URL")
        next
      end

      unless uri.is_a?(URI::HTTP) && uri.host.present?
        errors.add(:external_urls, "#{url.inspect} must be a valid http(s) URL")
      end
    end
  end

  def acceptable_uploads
    return unless attachments.attached?

    if attachments.size > MAX_ATTACHMENTS
      errors.add(:attachments, "cannot have more than #{MAX_ATTACHMENTS} files")
    end

    attachments.each do |attachment|
      blob = attachment.blob

      unless ALLOWED_UPLOAD_TYPES.include?(blob.content_type)
        errors.add(:attachments, "#{blob.filename} must be an image (JPEG, PNG, WebP, GIF) or a PDF")
      end

      next unless blob.byte_size > MAX_UPLOAD_BYTES

      errors.add(:attachments, "#{blob.filename} must be smaller than 10 MB")
    end
  end
end
