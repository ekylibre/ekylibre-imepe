# frozen_string_literal: true

class InvoiceXMLExportService
  def initialize(trade)
    @trade = trade
  end

  def export
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.piece do
        xml.id_exploitation MesParcelles::MesParcellesIntegration.fetch.parameters['siret_number']
        xml.type_           @trade.is_a?(Sale) ? 2 : 1
        xml.millesime       @trade.invoiced_at.year
        xml.date            @trade.invoiced_at
        xml.numero          @trade.number
        xml.numero_tiers    @trade.third.number
        xml.libelle_tiers   @trade.third.name

        xml.elements do
          @trade.items.each do |element|
            xml.element do
              xml.quantite    element.quantity
              xml.unite       element.variant.unit_name
              xml.prix_unit   element.unit_pretax_amount
              xml.taux_tva    element.tax.amount
              xml.prix_ht     element.pretax_amount
              xml.prix_ttc    element.amount
              xml.numero_amm  element.variant.france_maaid
              xml.commentaire element.annotation
            end
          end
        end
      end
    end
    builder.to_xml
  end

  def to_file(filepath, overwrite: false)
    if File.exist?(filepath) && !overwrite
      raise "File #{filepath} exists. Run #to_file(filepath, overwrite: true) to override"
    end

    File.write(filepath, CGI.unescapeHTML(export))
  end
end
