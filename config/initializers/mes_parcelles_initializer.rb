MesParcelles::MesParcellesIntegration.on_check_success do
  user_to_notify = Integration.find_by_nature('mes_parcelles').creator
  user_to_notify.notify(:land_parcels_from_imepe_import_started.tl)
  MesParcelles::MesParcellesLandParcelSyncJob.perform_later
end

MesParcelles::MesParcellesIntegration.run every: :day do
  MesParcelles::MesParcellesLandParcelSyncJob.perform_now
end

