# frozen_string_literal: true

require 'test_helper'
require_relative '../test_helper'

class MesParcellesLandParcelSyncJobTest < ActiveJob::TestCase
  include ActiveJob::TestHelper
  include FactoryBot::Syntax::Methods

  setup do
    VCR.use_cassette('auth-job') do
      user = create(:user)
      create(:integration, creator: user)
    end
  end

  def test_perform
    VCR.use_cassette('perform') do
      perform_enqueued_jobs do
        MesParcelles::MesParcellesLandParcelSyncJob.perform_now
      end
      assert_equal 'finished', Integration.find_by(nature: 'mes_parcelles').state,
                   'Should verify that the synchronisation state is finished'.red
    end
  end

  # Testing Synchronisation with a chosen year, here 2019
  def synchronisation_finished
    VCR.use_cassette('synchronisation_finished') do
      perform_enqueued_jobs do
        MesParcelles::MesParcellesLandParcelSyncJob.perform_now
      end
      integration_2019 = create(:integration, parameters: { harvest_year: '2019' })
      assert_equal 'finished', integration_2019.state, 'Should verify that the synchronisation state is finished'.red
    end
  end
end
