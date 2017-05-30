module Imepe
  class ImepeDataFetchingJob < ActiveJob::Base
    queue_as :default

    def perform
      Imepe::ImepeIntegration.get_exploitation_ids.execute do |c|
        c.success do |exploit_ids|
          zones        = exploit_ids.map { |id| create_cultivable_zone_from_id(id) }.flatten.compact
          land_parcels = zones
            .map do |z|
              create_land_parcels_from_zone(
                z.codes['imepe']['identification_number'],
                z.codes['imepe']['farm_id']
              )
            end
            .flatten
          land_parcels
        end
      end
    end

    private

    def create_cultivable_zone_from_id(id)
      Imepe::ImepeIntegration.get_cultivable_zone_data(id).execute do |call|
        call.success do |cultivable_zones|
          cultivable_zones.map do |cz|
            cz_id = cz['identifiant']
            Imepe::ImepeIntegration.get_cultivable_zone_geom(cz_id).execute do |c|
              c.success do |geom|
                create_cultivable_zone!(cz, geom)
              end
            end
          end
        end
      end
    end

    def create_land_parcels_from_zone(zone, farm)
      Imepe::ImepeIntegration.get_land_parcels_data(zone).execute do |call|
        call.success do |parcels|
          plant_infos = []
          perennial = false

          Imepe::ImepeIntegration.get_plant_list.execute do |cl|
            cl.success do |info|
              plant_infos = info
            end
          end

          parcels.map do |parcel|
            Imepe::ImepeIntegration.check_if_perennial(parcel).execute do |cl|
              cl.success do |status|
                perennial = status
              end
            end

            create_activity!(parcel, plant_infos, perennial)

            lp_id = parcel['identifiant']
            Imepe::ImepeIntegration.get_land_parcels_geom(lp_id, farm, parcel['millesime']).execute do |c|
              c.success do |geom|
                create_land_parcel!(parcel, geom)
              end
            end
          end
        end
      end
    end

    def create_cultivable_zone!(data, geom)
      return nil unless geom.present? && data['nom']
      CultivableZone.create!(
        name: data['nom'],
        work_number: data["numero"],
        shape: geom,
        codes: {
          imepe: {
            identification_number: data['identifiant'],
            farm_id: data['idExploitation']
          }
        }
      )
    end

    def create_land_parcel!(data, geom)
      LandParcel.create!(
        initial_shape: geom,
        variant: ProductNatureVariant.find_or_import!(:land_parcel).first,
        work_number: data['numero'],
        name: data['nom'],
        codes: {
          imepe: {
            identification_number: data['identifiant'],
            cultivable_zone_id: data['idilot'],
            year: data['millesime'],
            plant: {
              identification_number: data['culture']['identifiant'],
              label: data['culture']['libelle']
            },
            # variety: {
            #   identification_number: data['varietes']['variete']['identification'],
            #   label: data['libelle']
            # }
          }
        }
      )
    end

    def create_activity!(parcel_info, plant_info, perennial)
      plant = plant_info.find { |pl| pl['identifiant'] == parcel_info['culture']['identifiant'] }
      activity_name = parcel_info['culture']['libelle']
      similar = Activity.where("name ILIKE ?", activity_name + '%')
      activity_name += " - #{similar.count}" if similar.any?

      Activity.create!(
        production_cycle: perennial ? :perennial : :annual,
        # campaign: parcel_info['millesime']
        # TODO: connect the activity to the camaign
        name: activity_name,
        family: :plant_farming,
        codes: {
          imepe: {
            pac_variety_code: plant['codeculturepac']
          }
        }
        # TODO: Use plant_info['codeculturepac'] to fill in variety too.
      )
    end
  end
end
