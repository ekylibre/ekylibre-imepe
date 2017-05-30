MesParcelles::MesParcellesIntegration.on_check_success do
  MesParcelles::MesParcellesLandParcelSyncJob.perform_later
end

MesParcelles::MesParcellesIntegration.run every: :day do
  MesParcelles::MesParcellesLandParcelSyncJob.perform_now
end

