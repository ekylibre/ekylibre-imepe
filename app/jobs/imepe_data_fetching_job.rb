module Imepe
  class IemepeDataFetchingJob < ActiveJob::Base
    queue_as :default

    def perform
      Imepe::ImepeIntegration.get_exploitation_ids.execute do |c|
        c.success do |exploit_ids|
        end
      end
    end
  end
end
