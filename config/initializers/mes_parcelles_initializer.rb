MesParcelles::MesParcellesIntegration.on_check_success do
  user_to_notify = Integration.find_by_nature('mes_parcelles').creator
  user_to_notify.notify(:land_parcels_from_mes_parcelles_import_started.tl)
  MesParcelles::MesParcellesLandParcelSyncJob.perform_later
end

MesParcelles::MesParcellesIntegration.run every: :day do
  MesParcelles::MesParcellesLandParcelSyncJob.perform_now
end

Ekylibre::View::Addon.add(:backend_sales_show_main_toolbar,     'backend/trades/imepe_export_button')
Ekylibre::View::Addon.add(:backend_purchases_show_main_toolbar, 'backend/trades/imepe_export_button')

class Backend::PurchasesController < Backend::BaseController
  include MesParcelles::XMLExportAction
end

class Backend::SalesController < Backend::BaseController
  include MesParcelles::XMLExportAction
end
