require "jwt"

module JsonWebToken
  class InvalidToken < StandardError; end
  class ExpiredToken < InvalidToken; end

  ALGORITHM = "HS256".freeze
  ISSUER = "lect_and_nect".freeze
  ACCESS_TTL = 15.minutes
  REFRESH_TTL = 30.days

  ACCESS_TYPE = "access".freeze
  REFRESH_TYPE = "refresh".freeze

  module_function

  def encode_access(user)
    encode(user, ACCESS_TYPE, ACCESS_TTL)
  end

  def encode_refresh(user)
    encode(user, REFRESH_TYPE, REFRESH_TTL)
  end

  def decode_access(token)
    decode(token, ACCESS_TYPE)
  end

  def decode_refresh(token)
    decode(token, REFRESH_TYPE)
  end

  def access_ttl
    ACCESS_TTL.to_i
  end

  def encode(user, type, ttl)
    issued_at = Time.current
    payload = {
      sub: user.id.to_s,
      typ: type,
      iss: ISSUER,
      jti: SecureRandom.uuid,
      iat: issued_at.to_i,
      exp: (issued_at + ttl).to_i
    }

    JWT.encode(payload, secret, ALGORITHM)
  end

  def decode(token, expected_type)
    raise InvalidToken, "missing token" if token.blank?

    payload, = JWT.decode(token, secret, true, algorithm: ALGORITHM, iss: ISSUER, verify_iss: true)
    raise InvalidToken, "unexpected token type" unless payload["typ"] == expected_type

    payload
  rescue JWT::ExpiredSignature
    raise ExpiredToken, "token has expired"
  rescue JWT::DecodeError => e
    raise InvalidToken, e.message
  end

  def secret
    ENV["JWT_SECRET"].presence ||
      Rails.application.credentials.jwt_secret.presence ||
      Rails.application.secret_key_base
  end
end
