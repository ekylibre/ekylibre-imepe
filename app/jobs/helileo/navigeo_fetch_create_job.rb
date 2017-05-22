module Helileo
  class NavigeoFetchCreateJob < ActiveJob::Base
    queue_as :default

    def perform
      Helileo::NavigeoIntegration.get_devices.execute do |c|
        c.success do |devices|
          existing_sensors_euid = Sensor
                                  .where(vendor_euid: 'helileo')
                                  .pluck(:euid)
          fetched_devices_euid = devices.map { |device| device['serial_number'] }
          missing_sensors_euid = fetched_devices_euid - existing_sensors_euid
          new_devices = devices.select { |device| missing_sensors_euid.include? device['serial_number'] }
          new_devices.each do |new_device|
            serial = new_device['serial_number']
            Sensor.create!(
              name: "#{new_device['family']} #{serial}",
              vendor_euid: :helileo,
              model_euid: new_device['family'],
              euid: serial,
              retrieval_mode: :integration,
              embedded: true
            )

            token = Token.find_or_create_by(name: 'helileo')
            callback = ENV['HOST_DOMAIN_NAME']
            callback &&= Rails.application.routes.url_helpers.url_for(
              controller: '/ext/helileo/v1/locations',
              action: :create,
              token: token.value,
              host: "#{Ekylibre::Tenant.current}.#{ENV['HOST_DOMAIN_NAME']}",
              protocol: :https
            )
            callback ||= 'example.org'
            Helileo::NavigeoIntegration.set_location_hook(serial, callback).execute do |c|
              c.error do
                raise 'Could not set hooks.'
              end
            end
          end
        end
      end
    end
  end
end
