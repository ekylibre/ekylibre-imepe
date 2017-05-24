module Imepe
  class IemepeDataFetchingJob < ActiveJob::Base
    queue_as :default

    def perform
      Imepe::ImepeIntegration.get_exploitations.execute do |c|
        c.success do |devices|
        end
      end
    end
  end
end
