module Imepe
  class IemepeDataFetchingJob < ActiveJob::Base
    queue_as :default

    def perform
      Imepe::ImepeIntegration.get_exploitation_ids.execute do |c|
        c.success do |exploit_ids|
          zones        = exploit_ids.map { |id| create_cultivable_zone_from_id(id) }
          land_parcels = zones.map { |z| create_land_parcels_from_zone(z) }
          land_parcels
        end
      end
    end

    private

    def create_cultivable_zone_from_id(id)
      Imepe::ImepeIntegration.get_cultivable_zone_data.execute do |call|
        call.success do |data|
          Imepe::ImepeIntegration.get_cultivable_zone_geom.execute do |c|
            c.success do |geom|
              create_cultivable_zone!(data, geom)
            end
          end
        end
      end
    end

    def create_land_parcels_from_zone(zone)
      Imepe::ImepeIntegration.get_land_parcels_data(zone).execute do |call|
        call.success do |data|
          create_activity!(data)
          lp_id = data # TODO: Parse data
          Imepe::ImepeIntegration.get_land_parcels_geom(lp_id) do |c|
            c.success do |geom|
              create_land_parcel!(data, geom)
            end
          end
        end
      end
    end

    def create_cultivable_zone!(data, geom)
      # TODO: Implement
    end

    def create_land_parcel!(data, geom)
      # TODO: Implement
    end

    def create_activity!(data)
      # TODO: Implement
    end
  end
end
