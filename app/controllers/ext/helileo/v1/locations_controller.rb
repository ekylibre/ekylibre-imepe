module Ext
  module Helileo
    module V1
      class LocationsController < ActionController::Base
        include CallLoggable

        def create
          helileo_token = Token.find_by_name(:helileo)
          unless params['token'] == helileo_token.value
            render status: :unauthorized, json: { message: 'Unauthorized.' }
            return
          end
          Sensor
            .find_by_euid(params['device_serial_number'])
            .analyses
            .create!(
              retrieval_status: :ok,
              nature: :sensor_analysis,
              geolocation: {
                'type' => 'Point',
                'coordinates' => [
                  params['events'][0]['location']['longitude'],
                  params['events'][0]['location']['latitude']
                ]
              },
              sampling_temporal_mode: :instant
            )
          render status: :ok, json: { message: 'Location update received !' }
        end
      end
    end
  end
end
