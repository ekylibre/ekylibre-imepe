# frozen_string_literal: true

module MesParcelles
  module XMLExportAction
    extend ActiveSupport::Concern

    included do
      respond_to :xml
    end

    def mes_parcelles_extract
      @trade = controller_name.classify.constantize.find(params[:id])
      respond_with do |format|
        format.xml { render xml: InvoiceXMLExportService.new(@trade).export }
      end
    end
  end
end
