module Imepe
  class ImepeIntegration < ActionIntegration::Base
    auth :check do
      parameter :siret
    end
    calls :debug

    SERVER = "www.rhone-alpes.test.mesparcelles.fr"
    VERSION = '1.4'
    FORMAT = :xml

    def debug
      # integration = fetch
      get_format(url(:siga_web, :exploitations), headers) do |r|
        byebug
      end
    end

    def check(integration = nil)
      integration = fetch integration
      get_format(url(:siga_web, :exploitations), headers) do |r|
        r.success do
          sirets = Nokogiri::XML(r.body).css('exploitations exploitation identification siret').map(&:inner_text)
          there = sirets.include? integration.parameters['siret']
          there || r.error
        end
      end
    end

    private

    def url(application, service, server: SERVER, version: VERSION, format: FORMAT)
      "http://#{server}/apiService/#{version}/#{application}/#{service}.#{format}"
    end

    def headers
      username = 'Ekylibre'
      password = 'AiEcpa'

      nonce = rand(2**256).to_s(36)[0..7]
      created_at = Time.now.strftime("%Y-%m-%dT%TZ")

      hashed_password = Digest::SHA256.hexdigest(password)
      token = nonce + created_at + hashed_password
      digest = Digest::SHA1.hexdigest(token)
      digest = Base64.strict_encode64(digest)

      {
        "Authorization" => 'WSSE profile="UsernameToken"',
        "X-WSSE" => "UsernameToken Username=\"#{username}\", PasswordDigest=\"#{digest}\", Nonce=\"#{nonce}\", Created=\"#{created_at}\""
      }
    end

    def get_format(*args, &block)
      major_version = VERSION.split('.').first.to_i
      format = FORMAT.downcase.to_sym
      Rails.logger.warn 'IMEPE API v1 only supports the XML format !' if major_version <= 1 && format != :xml
      send(:"get_#{FORMAT}", *args, &block)
    end
  end
end
