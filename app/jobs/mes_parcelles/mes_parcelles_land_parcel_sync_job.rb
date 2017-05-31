module MesParcelles
  class MesParcellesLandParcelSyncJob < ActiveJob::Base
    queue_as :default

    def perform
      MesParcelles::MesParcellesIntegration.get_exploitation_ids.execute do |c|
        c.success do |exploit_ids|
          user_to_notify = Integration.find_by_nature('mes_parcelles').creator
          zones        = exploit_ids.map { |id| create_cultivable_zone_from_id(id) }.flatten.compact
          land_parcels = zones
            .map do |z|
              create_land_parcels_from_zone(
                z.codes['mes_parcelles']['identification_number'],
                z.codes['mes_parcelles']['farm_id']
              )
            end
            .flatten
          user_to_notify.notify(:land_parcels_from_mes_parcelles_imported.tl)
          land_parcels
        end
      end
    end

    private

    def create_cultivable_zone_from_id(id)
      MesParcelles::MesParcellesIntegration.get_cultivable_zone_data(id).execute do |call|
        call.success do |cultivable_zones|
          cultivable_zones.map do |cz|
            cz_id = cz['identifiant']
            MesParcelles::MesParcellesIntegration.get_cultivable_zone_geom(cz_id).execute do |c|
              c.success do |geom|
                create_cultivable_zone!(cz, geom)
              end
            end
          end
        end
      end
    end

    def create_land_parcels_from_zone(zone, farm)
      MesParcelles::MesParcellesIntegration.get_land_parcels_data(zone).execute do |call|
        call.success do |parcels|
          plant_infos = []
          perennial = false

          MesParcelles::MesParcellesIntegration.get_plant_list.execute do |cl|
            cl.success do |info|
              plant_infos = info
            end
          end

          parcels.map do |parcel|
            MesParcelles::MesParcellesIntegration.check_if_perennial(parcel).execute do |cl|
              cl.success do |status|
                perennial = status
              end
            end

            lp_id = parcel['identifiant']
            MesParcelles::MesParcellesIntegration.get_land_parcels_geom(lp_id, farm, parcel['millesime']).execute do |c|
              c.success do |geom|
                activity = create_activity!(parcel, plant_infos, perennial)
                create_land_parcel!(parcel, geom, activity, zone)
              end
            end
          end
        end
      end
    end

    def create_cultivable_zone!(data, geom)
      return nil unless geom.present? && data['nom']
      CultivableZone.where("codes #>> '{mes_parcelles,identification_number}' = ?", data['identifiant']).first ||
        CultivableZone.create!(
          name: data['nom'],
          work_number: data["numero"],
          shape: geom,
          codes: {
            mes_parcelles: {
              identification_number: data['identifiant'],
              farm_id: data['idExploitation']
            }
          }
        )
    end

    def create_land_parcel!(data, geom, activity, zone_id)
      name = data['nom']
      plant_label = data['culture']['libelle']
      year = data['millesime']
      pac_code = activity.codes['mes_parcelles']['pac_variety_code']
      abac = abac_info(pac_code, year)

      support_nature = (abac && abac.support_nature) || :cultivation

      prod = ActivityProduction.find_or_create_by!(
        activity: activity,
        campaign: Campaign.of(year),
        cultivable_zone: CultivableZone.where("codes #>> '{mes_parcelles,identification_number}' = ?", zone_id).first,
        support_shape: geom.to_ewkt,
        support_nature: support_nature,
        usage: abac && abac.usage
      )


      prod.support.update!(
        work_number: data['numero'],
        name: "#{prod.support.name} - #{name}",
        codes: {
          mes_parcelles: {
            identification_number: data['identifiant'],
            cultivable_zone_id: data['idilot'],
            year: year,
            plant: {
              identification_number: data['culture']['identifiant'],
              label: plant_label
            },
            # variety: {
            #   identification_number: data['varietes']['variete']['identification'],
            #   label: data['libelle']
            # }
          }
        }
      )
       prod.support
    end

    def create_activity!(parcel_info, plant_info, perennial)
      plant = plant_info.find { |pl| pl['identifiant'] == parcel_info['culture']['identifiant'] }
      activity_name = parcel_info['culture']['libelle']
      year = parcel_info['millesime']
      pac_code = plant['codeculturepac']

      activity = Activity.where(
        "codes #>> '{mes_parcelles,pac_variety_code}' = ? AND name = ?",
        pac_code,
        activity_name
      ).first

      variety = abac_info(pac_code, year).variety

      unless activity
        similar = Activity.where("name ILIKE ?", activity_name + '%')
        activity_name += " - #{similar.count}" if similar.any?

        activity = Activity.create!(
          production_cycle: perennial ? :perennial : :annual,
          name: activity_name,
          family: :plant_farming,
          cultivation_variety: variety,
          codes: {
            mes_parcelles: {
              pac_variety_code: pac_code
            }
          }
        )
      end

      activity.budgets.find_or_create_by!(campaign: Campaign.of(parcel_info['millesime']))
      activity

      # TODO: Use plant_info['codeculturepac'] to fill in variety too.
    end

    def abac_info(code, year = '2017')
      if File.directory?("#{CAP.abaci_dir}/v#{year}")
        variety = CAP::TelepacFile.find({ main_crop_code: code}.to_struct, year)
      end
      variety = CAP::TelepacFile.find({ main_crop_code: code}.to_struct, '2017') unless variety
      variety && variety.first
    end
  end
end
