module Imepe
  class ImepeIntegration < ActionIntegration::Base
    auth :check do
      parameter :siret_number
    end
    calls :debug

    SERVER = "www.rhone-alpes.test.mesparcelles.fr"
    API_VERSION = '1.4'
    FORMAT = :xml

    def debug
      # integration = fetch
      get_format(url(:siga_web, :exploitations)) do |r|
        byebug
      end
    end

    def check(integration = nil)
      integration = fetch integration
      get_format(url(:siga_web, :exploitations))
      # TODO: Add check on SIRET
    end

    private

    def url(application, service, server: SERVER, version: VERSION, format: FORMAT)
      "http://#{server}/apiService/#{version}/#{application}/#{service}.#{format}"
    end

    def get_format(*args, **kwargs, &block)
      send(:"get_#{FORMAT}", *args, **kwargs, &block)
    end
  end
end
