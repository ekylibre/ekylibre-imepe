# frozen_string_literal: true

module MesParcelles
  class MesParcellesIntegration < ActionIntegration::Base
    # base_url could be one of [normandie pdl rhones-alpes]
    # see option on imepe.js
    ID = 'sigaweb'
    SECRET = nil
    TOKEN_URL = ENV['MES_PARCELLES_TOKEN_URL']
    APPLICATION = 'SIGA_WEB'
    DOMAIN = ENV['MES_PARCELLES_DOMAIN']
    LOGIN = ENV['MES_PARCELLES_LOGIN']
    PASSWORD = ENV['MES_PARCELLES_PASSWORD']

    authenticate_with :check do
      parameter :base_url
      parameter :siret_number, readonly: true do
        Entity.of_company&.siret_number
      end
      parameter :harvest_year, readonly: true do
        Campaign.current&.last.harvest_year
      end
    end

    calls :get_exploitation_ids
    calls :get_cultivable_zones_from_exploitation_id
    calls :get_cultivable_zone_geom_from_id
    calls :get_land_parcel_data_from_farm
    calls :get_land_parcels_geom_from_parcel
    calls :get_plant_list_from_farm
    calls :check_if_perennial_from_parcel

    def check(integration = nil)
      integration = fetch integration
      siret_number = integration.parameters['siret_number']
      get_json(url(integration, 'exploitations', { application: APPLICATION, siret: siret_number }),
               headers(integration)) do |r|
        r.success do
          resp = JSON.parse(r.body)
          sirets = resp['exploitations'].map do |exploitation|
            exploitation['exploitation']['identification']['siret']
          end
          sirets.include? siret_number || r.error(:siret_number_not_found)
        end
      end
    end

    # Plural because "whose sirets we have" even tho for now we only have one
    # siret per integration rn.
    def get_exploitation_ids
      integration = fetch
      siret_number = integration.parameters['siret_number']
      get_json(url(integration, 'exploitations', { application: APPLICATION, siret: siret_number }),
               headers(integration)) do |r|
        r.success do
          resp = JSON.parse(r.body)
          resp['exploitations'].map do |exploitation|
            exploitation['exploitation']['identification']['identifiant']
          end
        end
      end
    end

    # get ilots datas
    def get_cultivable_zones_from_exploitation_id(exploitation_id)
      integration = fetch
      harvest_year = integration.parameters['harvest_year']
      get_json(url(integration, 'ilots', { idexploitation: exploitation_id, millesime: harvest_year }),
               headers(integration)) do |r|
        r.success do
          resp = JSON.parse(r.body)
          resp['ilots'].map do |ilot|
            ilot = ilot['ilot']
            id = ilot['identifiant']
            uuid = ilot['cleilotuuid']
            work_number = ilot['numero']
            town_reference_name = ilot['refNormeCommune']
            name = ilot['nom']
            farm_id = ilot['idExploitation']
            { id: id, uuid: uuid, work_number: work_number, name: name, farm_id: farm_id, town_reference_name: town_reference_name}
          end
        end
      end
    end

    # get ilots geom
    def get_cultivable_zone_geom_from_id(cultivable_zone_id)
      integration = fetch
      get_json(url(integration, "geom/ilot/#{cultivable_zone_id}"), headers(integration)) do |r|
        r.success do
          resp = JSON.parse(r.body)
          geom_cz = resp['geom_ilot']['geom']
          if geom_cz.blank?
            ''
          else
            geom_cz.to_json
          end
        end
      end
    end

    # get parcel datas
    def get_land_parcel_data_from_farm(farm, idilot)
      integration = fetch
      harvest_year = integration.parameters['harvest_year']
      get_json(url(integration, 'parcelles', { idexploitation: farm, millesime: harvest_year, idilot: idilot}),
               headers(integration)) do |r|
        r.success do
          resp = JSON.parse(r.body)
          parcels = resp['parcelles']
          parcels.map do |parcel|
            parcel_datas = {}
            parcel = parcel['parcelle']
            parcel_datas['identifiant'] = parcel['identifiant']
            parcel_datas['uuid'] = parcel['cleparcelleculturaleuuid']
            parcel_datas['millesime'] = parcel['millesime']
            parcel_datas['idilot'] = parcel['idilot']
            parcel_datas['name'] = parcel['nom']
            parcel_datas['work_number'] = parcel['numero']
            if parcel['culture']
              parcel_datas['plant_id'] = parcel['culture']['identifiant']
              parcel_datas['plant_label'] = parcel['culture']['libelle']
            else
              parcel_datas['plant_id'] = nil
              parcel_datas['plant_label'] = nil
            end
            parcel_datas
          end
        end
        r.error do
          puts "API ERROR : #{JSON.parse(r.body)['error']['message']}".inspect.red
        end
      end
    end

    # get culture
    def get_plant_list_from_farm(_farm)
      integration = fetch
      get_json(url(integration, 'cultures'), headers(integration)) do |r|
        r.success do
          resp = JSON.parse(r.body)
          plants = resp['cultures']

          plants.map do |plant|
            plant_list = {}
            plant = plant['culture']
            plant_list['plant_name'] = plant['libelle']
            plant_list['plant_id'] = plant['identifiant']
            plant_list['plant_agroedi_crop_code'] = plant['libelleedi'] if plant['libelleedi']
            plant_list['plant_agroedi_specie_code'] = plant['idespeceedi'] if plant['idespeceedi']
            plant_list['plant_cap_crop_code'] = plant['libellerpg'] if plant['libellerpg']
            plant_list['plant_cap_campaign'] = plant['millesimeinvaliditepac'] if plant['millesimeinvaliditepac']
            plant_list
          end
        end
        r.error do
          puts "API ERROR : #{JSON.parse(r.body)['error']['message']}".inspect.red
        end
      end
    end

    # check if perennial (month or year)
    def check_if_perennial_from_parcel(parcel)
      integration = fetch
      get_json(url(integration, 'occupationssol', { idparcelleculturale: parcel['identifiant'] }),
               headers(integration)) do |r|
        r.success do
          resp = JSON.parse(r.body)
          occupationssols = resp['occupationssol']
          occupationssols[0]['occupationsol']['perenne']
        end
      end
    end

    # get parcel datas
    def get_land_parcels_geom_from_parcel(parcel)
      integration = fetch
      get_json(url(integration, "geom/ilot/#{parcel['idilot']}"), headers(integration)) do |r|
        r.success do
          resp = JSON.parse(r.body)
          lp = resp['geom_ilot']['parcelles'].find { |p| p['geom_parcelle']['identifiant'] == parcel['identifiant'] }
          geom_lp = lp['geom_parcelle']['geom'] if lp
          if geom_lp.blank? || geom_lp.nil?
            ''
          else
            geom_lp.to_json
          end
        end
      end
    end

    private

    # url method used for all the requests
    def url(integration, object, url_args = {})
      base_url = integration.parameters['base_url']
      url_string = "https://#{base_url}.#{DOMAIN}/api/#{object}"

      return url_string if url_args.empty?

      if url_args.is_a?(Hash)
        url_args.each_with_index do |(key, value), index|
          args = "#{key}=#{value}"
          if index.zero?
            url_string += "?#{args}"
          else
            url_string += "&#{args}"
          end
        end
      end
      url_string
    end

    # access token
    def get_token(base_url)
      client = OAuth2::Client.new(ID,
                                  SECRET,
                                  token_url: TOKEN_URL,
                                  site: "https://#{base_url}.#{DOMAIN}")
      client.password.get_token(LOGIN, PASSWORD).token
    rescue OAuth2::Error => e
      puts 'Something went wrong. Please check the previous informations'
    end

    # set headers params
    def headers(integration)
      base_url = integration.parameters['base_url']
      access_token = get_token(base_url)
      { authorization: "Bearer #{access_token}", accept: 'application/json' }
    end
  end
end
