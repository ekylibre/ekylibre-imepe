module Helileo
  class NavigeoIntegration < ActionIntegration::Base
    auth :check do
      parameter :access_token
    end
    calls :get_devices, :get_device, :set_location_hook, :unset_hooks, :get_hooks, :debug

    def get_devices
      integration = fetch
      get_json("http://gateway.cloud.helileo.com/api/devices?access-token=#{integration.parameters['access_token']}") do |r|
        r.success do
          JSON(r.body).map(&:with_indifferent_access)
        end
      end
    end

    def get_device(serial_number)
      integration = fetch
      get_json("http://gateway.cloud.helileo.com/api/devices/#{serial_number}?access-token=#{integration.parameters['access_token']}") do |r|
        r.success do
          JSON(r.body).with_indifferent_access
        end
      end
    end

    def set_location_hook(serial_number, callback)
      integration = fetch
      payload = { 'event' => '0', 'callback' => callback.to_s }
      post_json("http://gateway.cloud.helileo.com/api/devices/#{serial_number}/hooks?access-token=#{integration.parameters['access_token']}", payload) do |r|
        r.success do
          JSON(r.body).with_indifferent_access
        end
      end
    end

    def unset_hooks(serial_number, matching = nil)
      integration = fetch
      get_json("http://gateway.cloud.helileo.com/api/devices/#{serial_number}/hooks?access-token=#{integration.parameters['access_token']}") do |r|
        r.success do
          JSON(r.body).each do |hook|
            next unless matching.present? && Regexp.new(matching).match(hook['callback']).present?
            delete_json("http://gateway.cloud.helileo.com/api/hooks/#{hook['id']}?access-token=#{integration.parameters['access_token']}")
          end
        end
      end
    end

    def get_hooks(serial_number)
      integration = fetch
      get_json("http://gateway.cloud.helileo.com/api/devices/#{serial_number}/hooks?access-token=#{integration.parameters['access_token']}") do |r|
        r.success do
          JSON(r.body).map(&:with_indifferent_access)
        end
      end
    end

    def debug
      integration = fetch
      get_json("http://gateway.cloud.helileo.com/api/devices?access-token=#{integration.parameters['access_token']}") do |r|
      end
    end

    def check(integration = nil)
      integration = fetch integration
      get_json("http://gateway.cloud.helileo.com/api/access_tokens/#{integration.parameters['access_token']}") do |r|
        r.success do
          Rails.logger.info 'CHECKED'.green
        end
      end
    end
  end
end
