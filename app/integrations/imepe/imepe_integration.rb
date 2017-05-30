module Imepe
  class ImepeIntegration < ActionIntegration::Base
    auth :check do
      parameter :siret
    end
    calls :debug
    calls :get_exploitation_ids
    calls :get_cultivable_zone_data
    calls :get_cultivable_zone_geom
    calls :get_land_parcels_data
    calls :get_land_parcels_geom
    calls :get_plant_list
    calls :check_if_perennial

    SERVER = "www.rhone-alpes.test.mesparcelles.fr"
    VERSION = '1.4'
    FORMAT = :xml

    def debug
      # integration = fetch
      get_format(url(:siga_web, :exploitations), headers) do |r|
        byebug
      end
    end

    def check(integration = nil)
      integration = fetch integration
      get_format(url(:siga_web, :exploitations), headers) do |r|
        r.success do
          sirets = Nokogiri::XML(r.body).css('exploitations exploitation identification siret').map(&:inner_text)
          there = sirets.include? integration.parameters['siret']
          there || r.error
        end
      end
    end

    # Plural because "whose sirets we have" even tho for now we only have one
    # siret per integration rn.
    def get_exploitation_ids
      integration = fetch
      get_format(url(:siga_web, :exploitations), headers) do |r|
        r.success do
          siret = integration.parameters['siret']
          body = Nokogiri::XML(r.body)
          exploitations = body.css('exploitations exploitation identification')
          exploitations = exploitations.select { |exp| exp.css('siret').inner_text == siret }
          exploitations.map { |exp| exp.css('identifiant').inner_text }
        end
      end
    end

    def get_cultivable_zone_data(id)
      get_format(url(:siga_web, [:exploitations, id, :millesime, Date.current.year, :ilots]), headers) do |r|
        r.success do
          body = Nokogiri::XML(r.body)
          zones = body.css('ilots ilot')
          zones.map { |zone| Hash.from_xml(zone.to_s)['ilot'] }
        end
      end
    end

    def get_cultivable_zone_geom(id)
      get_format(url(:siga_web, [:ilots, id, :geom]), headers) do |r|
        r.success do
          body = Nokogiri::XML(r.body)
          if body.css('geom_ilot geom *').empty?
            []
          else
            geometry = body.xpath('.//gml:Polygon').first
            geometry.tap do |geom|
              # 'A B C D' => 'A,B C,D'
              pos_list = geom.xpath('.//gml:posList').first
              coordinates = pos_list
                .content
                .split(' ')
                .each_slice(2)
                .map { |coords| coords.join(',') }
                .join(' ')

              pos_list.content = coordinates
            end

            parsable_gml = geometry.to_xml.to_s
                                          .gsub('exterior', 'outerBoundaryIs')
                                          .gsub(' srsDimension="2"', "")
                                          .gsub('posList', 'coordinates')
                                          .squish

            ::Charta.from_gml(parsable_gml, 2154).transform(:WGS84).multi_polygon
          end
        end
      end
    end

    def get_land_parcels_data(id)
      get_format(url(:siga_web, [:ilots, id, :parcelles]), headers) do |r|
        r.success do
          body = Nokogiri::XML(r.body)
          parcels = body.css('parcelles parcelle')
          parcels.map do |parcel|
            Hash.from_xml(parcel.to_s)['parcelle']
          end
        end
      end
    end

    def get_land_parcels_geom(id, farm_id, year)
      get_format(url(:siga_web, [:exploitations, farm_id, :millesime, year, :ilots, :geom]), headers) do |r|
        r.success do
          body = Nokogiri::XML(r.body)
          matching_parcel = body.xpath("//geom_ilots/geom_ilot/parcelles/geom_parcelle/identifiant[text() = '#{id}']/../geom")
          if matching_parcel.empty?
            []
          else
            matching_parcel = matching_parcel.xpath('.//gml:Polygon').first
            matching_parcel.tap do |geom|
              # 'A B C D' => 'A,B C,D'
              pos_list = geom.xpath('.//gml:posList').first
              coordinates = pos_list
                .content
                .split(' ')
                .each_slice(2)
                .map { |coords| coords.join(',') }
                .join(' ')

              pos_list.content = coordinates
            end

            parsable_gml = matching_parcel.to_xml.to_s
                                          .gsub('exterior', 'outerBoundaryIs')
                                          .gsub(' srsDimension="2"', "")
                                          .gsub('posList', 'coordinates')
                                          .squish

            ::Charta.from_gml(parsable_gml, 2154).transform(:WGS84).multi_polygon
          end
        end
      end
    end

    def get_plant_list
      get_format(url(:siga_web, :cultures), headers) do |r|
        r.success do
          plants = Nokogiri::XML(r.body)
          plants.css('cultures culture').map do |plant|
            Hash.from_xml(plant.to_s)['culture'].slice('identifiant', 'libelle', 'codeculturepac')
          end
        end
      end
    end

    def check_if_perennial(parcel)
      get_format(url(:siga_web, [:parcelles, parcel["identifiant"], :occupationssol, parcel["culture"]["identifiant"]]), headers) do |r|
        r.success do
          Nokogiri::XML(r.body).css('occupationssol perenne').inner_text
        end
      end
    end

    private

    def url(application, service, server: SERVER, version: VERSION, format: FORMAT)
      service = service.join('/') if service.respond_to? :join
      "http://#{server}/apiService/#{version}/#{application}/#{service}.#{format}"
    end

    def headers
      username = 'Ekylibre'
      password = 'AiEcpa'

      nonce = rand(2**256).to_s(36)[0..7]
      created_at = Time.now.strftime("%Y-%m-%dT%TZ")

      hashed_password = Digest::SHA256.hexdigest(password)
      token = nonce + created_at + hashed_password
      digest = Digest::SHA1.hexdigest(token)
      digest = Base64.strict_encode64(digest)

      {
        "Authorization" => 'WSSE profile="UsernameToken"',
        "X-WSSE" => "UsernameToken Username=\"#{username}\", PasswordDigest=\"#{digest}\", Nonce=\"#{nonce}\", Created=\"#{created_at}\""
      }
    end

    def get_format(*args, &block)
      major_version = VERSION.split('.').first.to_i
      format = FORMAT.downcase.to_sym
      Rails.logger.warn 'IMEPE API v1 only supports the XML format !' if major_version <= 1 && format != :xml
      send(:"get_#{FORMAT}", *args, &block)
    end
  end
end
