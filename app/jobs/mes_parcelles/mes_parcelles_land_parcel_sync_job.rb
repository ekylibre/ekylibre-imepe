module MesParcelles
  class MesParcellesLandParcelSyncJob < ActiveJob::Base
    queue_as :default

    VENDOR = 'mes_parcelles'
    SRID = 2154

    def perform
      @job_id = Time.zone.now.iso8601
      @logger ||= Logger.new(File.join(Rails.root, 'log', "imepe-#{Ekylibre::Tenant.current.to_s}.log"))
      integration = MesParcelles::MesParcellesIntegration.fetch
      user_to_notify = integration.creator
      integration.update_column(:state, 'in_progress')
      @logger.info('----------------------------------------------------------------')
      # create cultivable_zones from exploitation
      MesParcelles::MesParcellesIntegration.get_exploitation_ids.execute do |c|
        c.success do |exploitation_ids|
          exploitation_ids.map do |exploitation_id|
            @logger.info("## -- exploitation_id : #{exploitation_id}")
            @logger.info('## -- START create_cultivable_zones_from_exploitation_id')
            create_cultivable_zones_from_exploitation_id(exploitation_id)
            @logger.info('## -- END create_cultivable_zones_from_exploitation_id')
            # create land_parcels from zone
            @logger.info('## -- START create_land_parcels_from_zone')
            create_land_parcels_from_exploitation_id(exploitation_id)
            @logger.info('## -- END create_land_parcels_from_zone')
          end
        end
      end

      integration.update_columns(last_sync_at: Time.zone.now, state: 'finished')
      user_to_notify.notify(:land_parcels_from_mes_parcelles_imported.tl)
    rescue StandardError => e
      @logger.error(e)
      ExceptionNotifier.notify_exception($ERROR_INFO, data: { message: e })
      notification = user_to_notify.notifications.build(error_notification_params(e))
    end

    private

    def error_notification_params(error)
      {
        message: 'error_during_mes_parcelles_api_call',
        level: :error,
        target_type: '',
        target_url: '',
        interpolations: {
          error_message: error
        }
      }
    end

    # create ilot (w/ datas & geom)
    def create_cultivable_zones_from_exploitation_id(exploitation_id)
      MesParcelles::MesParcellesIntegration.get_cultivable_zones_from_exploitation_id(exploitation_id).execute do |call|
        call.success do |cultivable_zones|
          cultivable_zones.map do |cultivable_zone|
            cultivable_zone_id = cultivable_zone[:id]
            MesParcelles::MesParcellesIntegration.get_cultivable_zone_geom_from_id(cultivable_zone_id).execute do |c|
              c.success do |geom_cz|
                create_cultivable_zone!(cultivable_zone, geom_cz)
              end
            end
          end
        end
      end
    end

    # create parcels (w/ datas, culture, perennial & geom)
    def create_land_parcels_from_exploitation_id(farm)

      MesParcelles::MesParcellesIntegration.get_plant_list_from_farm(farm).execute do |cl|
        cl.success do |info|
          @logger.info('API get_plant_list_from_farm OK')
          @plant_infos = info
        end
      end
      # create parcel for each cz
      CultivableZone.of_provider_vendor(VENDOR).each do |cultivable_zone|
        MesParcelles::MesParcellesIntegration.get_land_parcel_data_from_farm(farm, cultivable_zone.provider[:data]['id']).execute do |call|
          call.success do |parcels|
            @logger.info('API get_land_parcel_data_from_farm OK')

            parcels.map do |parcel|
              @logger.info("Start processing parcel | name : #{parcel['name']} , identifiant : #{parcel['identifiant']}")
              # get geom of the current parcel
              MesParcelles::MesParcellesIntegration.get_land_parcels_geom_from_parcel(parcel).execute do |c|
                c.success do |geom|
                  @logger.info('API get_land_parcels_geom_from_parcel OK')
                  # find the plant info for the current parcel
                  plant = @plant_infos.find { |pl| pl['plant_id'] == parcel['plant_id'] } if parcel['plant_id']
                  if plant.presence
                    @logger.info("plant_infos crop_code is #{plant['plant_cap_crop_code']}")
                  else
                    @logger.error("plant_infos crop_code (#{parcel['plant_id']}) is unkown for parcel name (#{parcel['name']})")
                  end
                  if plant.presence && !geom.blank?
                    @logger.info("# ----- Start creating activity")
                    activity = create_activity!(parcel, plant)
                    @logger.info("# ----- End creating activity")
                    @logger.info("# ----- Start creating land_parcel")
                    create_land_parcel!(parcel, geom, activity) if activity
                    @logger.info("# ----- End creating land_parcel")
                  else
                    @logger.error("Plant is nil or geom is blank for #{parcel['name']}")
                  end
                end
              end
            end
          end
        end
      end

    end

    # create CZ
    def create_cultivable_zone!(data, geom_cz)
      return nil if geom_cz.blank? || data[:name].nil?

      cz = CultivableZone.of_provider_vendor(VENDOR).of_provider_data(:id, data[:id].to_s).first
      # update if exist
      if cz
        cz.name = data[:name]
        cz.uuid = data[:uuid]
        cz.work_number = data[:work_number]
        cz.shape = fix_shape(geom_cz)
        cz.save!
        @logger.info("CZ updated : #{cz.name}")
      # or create it
      else
        cz = CultivableZone.create!(
          name: data[:name],
          uuid: data[:uuid],
          work_number: data[:work_number],
          shape: fix_shape(geom_cz),
          provider: {
            vendor: VENDOR,
            id: @job_id,
            name: 'ilot',
            data: { id: data[:id].to_s, farm_id: data[:farm_id].to_s }
          }
        )
        @logger.info("CZ created : #{cz.name}")
      end
      cz
    end

    #  create land_parcel
    def create_land_parcel!(data, geom_lp, activity)
      name = data['name']
      plant_label = data['plant_label']
      year = data['millesime']
      pac_code = activity['codes']['mes_parcelles']['plant_cap_crop_code']
      support_nature = :cultivation
      cz = CultivableZone.of_provider_vendor(VENDOR).of_provider_data(:id, data['idilot'].to_s).first
      support_shape = fix_shape(geom_lp)
      master_crop_production = MasterCropProduction.find_by(reference_name: activity.reference_name)
      @logger.error("Lexicon reference_name is missing for #{activity.reference_name}") unless master_crop_production.present?

      if master_crop_production.present?
        if activity&.production_cycle == :perennial
          prod = ActivityProduction.find_or_create_by!(
            activity: activity,
            cultivable_zone: cz,
            started_on: master_crop_production.start_on(year),
            support_shape: support_shape.to_rgeo,
            support_nature: support_nature,
            usage: master_crop_production.usage
          )
        elsif activity&.production_cycle == :annual
          prod = ActivityProduction.find_or_create_by!(
            activity: activity,
            campaign: Campaign.of(year),
            cultivable_zone: cz,
            started_on: master_crop_production.start_on(year),
            stopped_on: master_crop_production.stop_on(year),
            support_shape: support_shape.to_rgeo,
            support_nature: support_nature,
            usage: master_crop_production.usage
          )
        end

        prod.support.update!(
          work_number: data['work_number'],
          uuid: data['uuid'],
          name: "#{prod.support.name} - #{name}",
          provider: {
            vendor: VENDOR,
            id: @job_id,
            data: {
              identification_number: data['identifiant'],
              cultivable_zone_id: data['idilot'],
              year: year,
              plant: {
                identification_number: data['plant_id'],
                label: plant_label
              }
            }
          }
        )
        @logger.info("Production Support updated for ActivityProduction  ID : #{prod.id}")
        prod.support
      end
    end

    # create activity
    def create_activity!(parcel_info, plant)
      year = parcel_info['millesime']
      pac_code = plant['plant_cap_crop_code']
      edi_code = plant['plant_agroedi_crop_code']

      production_reference = lexicon_info(pac_code, year, edi_code)
      # break if no reference in Lexicon for plant code from IMEPE
      @logger.error("Lexicon reference does not exist for pac_code : #{pac_code}, year : #{year} and edi_code : #{edi_code}") if production_reference.reference_name.nil?
      return nil if production_reference.reference_name.nil?

      # find activity by cap_crop_code in provider
      activity = Activity.where(
        "codes #>> '{mes_parcelles,plant_cap_crop_code}' = ? AND codes #>> '{mes_parcelles,plant_name}' = ?",
        pac_code,
        plant['plant_name']
      ).first
      @logger.info("Activity exist : #{activity.name}") if activity
      return activity if activity

      # find activity by cap_crop_code in production_nature
      activity = Activity.find_by(reference_name: production_reference.reference_name)
      if activity
        activity.codes = { mes_parcelles: { plant_cap_crop_code: pac_code, plant_name: plant['plant_name'] } }
        @logger.info("Activity updated with codes : #{pac_code} and #{plant['plant_name']}")
      else
        activity = Activity.new(
          name: production_reference.name,
          nature: :main,
          family: Activity.find_best_family(production_reference.cultivation_variety).name,
          size_indicator: 'net_surface_area',
          size_unit: 'hectare',
          with_cultivation: true,
          with_supports: true,
          reference_name: production_reference.reference_name,
          cultivation_variety: production_reference.cultivation_variety,
          production_started_on: production_reference.production_started_on,
          production_stopped_on: production_reference.production_stopped_on,
          production_started_on_year: production_reference.production_started_on_year,
          production_stopped_on_year: production_reference.production_stopped_on_year,
          life_duration: production_reference.life_duration,
          codes: {
            mes_parcelles: {
              plant_cap_crop_code: pac_code,
              plant_name: plant['plant_name']
            }
          }
        )
        if production_reference.life_duration&.to_d > 1
          activity.production_cycle = :perennial
          activity.start_state_of_production_year = 1
        end
        @logger.info("Activity new : #{activity.name}")
      end
      if activity.save!
        @logger.info("Activity save : #{activity.name}")
        activity.budgets.find_or_create_by!(campaign: Campaign.of(parcel_info['millesime']))
        activity
      else
        @logger.error("Activity error during save : #{activity.name}")
        nil
      end
    end

    # fix shape if needed
    def fix_shape(geom)
      shape_fix = ShapeCorrector.build.try_fix_geojson(geom, SRID)
      ::Charta.new_geometry(shape_fix.or_raise).transform(:WGS84).convert_to(:multi_polygon)
    end

    # check in Lexicon
    def lexicon_info(code, year = Date.current.year, edi_code = nil)
      attrs = {
        name: nil,
        reference_name: nil,
        cultivation_variety: nil,
        production_started_on: nil,
        production_stopped_on: nil,
        production_started_on_year: nil,
        production_stopped_on_year: nil,
        life_duration: nil,
        usage: nil
      }
      cap_year = [2017, year].max
      lexicon_production_nature = MasterCropProduction.joins(:cap_codes)
                                                      .where('master_crop_production_cap_codes.cap_code = ? AND master_crop_production_cap_codes.year = ?', code, cap_year).first

      @logger.error("The crop_code (#{code}) was not found in the lexicon") if lexicon_production_nature.nil?
      # try to find with agroedi crop code
      lexicon_production_nature ||= MasterCropProduction.find_by(agroedi_crop_code: edi_code) if edi_code
      @logger.error("The edi_code (#{edi_code}) was not found in the lexicon") if edi_code && lexicon_production_nature.nil?

      return attrs.to_struct if lexicon_production_nature.nil?

      # set attributes
      attrs.update(
        name: lexicon_production_nature.translation.send(Preference[:language]),
        reference_name: lexicon_production_nature.reference_name,
        cultivation_variety: lexicon_production_nature.specie,
        production_started_on: lexicon_production_nature.start_on(year).change(year: 2000),
        production_stopped_on: lexicon_production_nature.stop_on(year).change(year: 2000),
        production_started_on_year: lexicon_production_nature.started_on_year,
        production_stopped_on_year: lexicon_production_nature.stopped_on_year,
        life_duration: (lexicon_production_nature.life_duration.present? ? lexicon_production_nature.life_duration.parts[:years] : 1),
        usage: lexicon_production_nature.usage
      )

      attrs.to_struct
    end
  end
end
