Imepe::ImepeIntegration.on_check_success do
  Imepe::ImepeDataFetchingJob.perform_later
end

Imepe::ImepeIntegration.run every: :day do
  Imepe::ImepeDataFetchingJob.perform_now
end

