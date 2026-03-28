# frozen_string_literal: true

require 'test_helper'
require_relative '../test_helper'

class ImepeIntegrationTest < ::Ekylibre::Testing::ApplicationTestCase::WithFixtures
  setup do
    VCR.use_cassette('auth-integration') do
      user = create(:user)
      create(:integration, creator: user)
    end
  end

  def test_get_exploitation_ids
    VCR.use_cassette('get_exploitation_ids') do
      MesParcelles::MesParcellesIntegration.get_exploitation_ids.execute do |call|
        call.success do |response|
          assert_equal Array, response.class, 'Should return an array'.red
          assert_equal Integer, response.first.class, 'Should return an id so an integer'
        end
      end
    end
  end

  def test_get_cultivable_zones_from_exploitation_id
    VCR.use_cassette('get_cultivable_zones_from_exploitation_id') do
      MesParcelles::MesParcellesIntegration.get_cultivable_zones_from_exploitation_id('1').execute do |call|
        call.success do |response|
          assert_equal Array, response.class, 'Should return an Array'.red
          assert_equal Hash, response.first.class, 'Should return a Hash'.red
          response.each { |s| assert %i[id uuid work_number name farm_id], s.keys }
        end
      end
    end
  end

  def test_get_cultivable_zone_geom_from_id
    VCR.use_cassette('get_cultivable_zone_geom_from_id') do
      MesParcelles::MesParcellesIntegration.get_cultivable_zone_geom_from_id('1708221').execute do |call|
        call.success do |response|
          assert_equal String, response.class, 'Should return a String'.red
        end
      end
    end
  end

  def test_get_land_parcel_data_from_farm
    VCR.use_cassette('get_land_parcel_data_from_farm') do
      MesParcelles::MesParcellesIntegration.get_land_parcel_data_from_farm('1').execute do |call|
        call.success do |response|
          assert_equal Array, response.class, 'Should return an Array'.red
          assert_equal Hash, response.first.class, 'Should return an Hash'.red
          response.each { |s| assert %i[identifiant millesime idilot name work_number], s.keys }
        end
      end
    end
  end

  def test_get_plant_list_from_farm
    VCR.use_cassette('get_plant_list_from_farm') do
      MesParcelles::MesParcellesIntegration.get_plant_list_from_farm('1').execute do |call|
        call.success do |response|
          assert_equal Array, response.class, 'Should return an Array'.red
          assert_equal Hash, response.first.class, 'Should return a  Hash'.red
          response.each { |s| assert %i[plant_name plant_id plant_agroedi_specie_code plant_cap_crop_code], s.keys }
        end
      end
    end
  end

  def test_get_land_parcels_geom_from_parcel
    VCR.use_cassette('get_land_parcels_geom_from_parcel') do
      MesParcelles::MesParcellesIntegration.get_land_parcels_geom_from_parcel('identifiant' => 2_705_935,
                                                                              'millesime' => 2020, 'idilot' => 1_708_224, 'name' => 'parcelle n°24', 'work_number' => 18).execute do |call|
        call.success do |response|
          assert_equal String, response.class, 'Should return a JSON String'.red
          assert_equal true, response.include?('Polygon'), 'Should return Polygon format'.red
          assert response.include?('coordinates'), 'Should return coordinates'.red
        end
      end
    end
  end
end
