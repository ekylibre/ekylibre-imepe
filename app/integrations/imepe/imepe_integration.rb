module Imepe
  class ImepeIntegration < ActionIntegration::Base
    auth :check do
      parameter :siret_number
    end
    calls :get_devices, :get_device, :set_location_hook, :unset_hooks, :get_hooks, :debug

    def debug
      integration = fetch
      get_json("http://gateway.cloud.imepe.com/api/devices?access-token=#{integration.parameters['access_token']}") do |r|
      end
    end

    def check(integration = nil)
      integration = fetch integration
      get_json("http://gateway.cloud.imepe.com/api/access_tokens/#{integration.parameters['access_token']}") do |r|
        r.success do
          Rails.logger.info 'CHECKED'.green
        end
      end
    end
  end
end
