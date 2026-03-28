module EkylibreImepe
  class Engine < ::Rails::Engine

    initializer 'ekylibre_imepe.assets.precompile' do |app|
      app.config.assets.precompile += %w[imepe.js integrations/mes_parcelles.png]
    end

    initializer :i18n do |app|
      app.config.i18n.load_path += Dir[EkylibreImepe::Engine.root.join('config', 'locales', '**', '*.yml')]
    end

    initializer 'ekylibre_imepe.integration' do
      MesParcelles::MesParcellesIntegration.on_check_success do
        user_to_notify = Integration.find_by_nature('mes_parcelles').creator
        user_to_notify.notify(:land_parcels_from_mes_parcelles_import_started.tl)
        MesParcelles::MesParcellesLandParcelSyncJob.perform_later
      end

      MesParcelles::MesParcellesIntegration.run every: :day do
        MesParcelles::MesParcellesLandParcelSyncJob.perform_later
      end

      Ekylibre::View::Addon.add(:backend_sales_show_main_toolbar,     'backend/trades/imepe_export_button')
      Ekylibre::View::Addon.add(:backend_purchases_show_main_toolbar, 'backend/trades/imepe_export_button')

      class Backend::PurchasesController < Backend::BaseController
        include MesParcelles::XMLExportAction
      end

      class Backend::SalesController < Backend::BaseController
        include MesParcelles::XMLExportAction
      end
    end

    initializer :ekylibre_baqio_imepe_javascript do
      tmp_file = Rails.root.join('tmp', 'plugins', 'javascript-addons', 'plugins.js.coffee')
      tmp_file.open('a') do |f|
        import = '#= require imepe'
        f.puts(import) unless tmp_file.open('r').read.include?(import)
      end
    end

  end
end
