# Ekylibre Imepe

This sub-project uses Proprietary LICENSE. <br>

## Installation (from version 0.5 - need Ekylibre >= 3.30.0)

Add this line to your application's Gemfile:

```ruby
gem 'ekylibre_imepe', git: 'git@gitlab.com:ekylibre/ekylibre-imepe.git'
```

or in development mode, you can clone the repository in 'ekylibre-imepe' folder near ekylibre and then add in your ekylibre gemfile :

```ruby
gem 'ekylibre_imepe', path: '../ekylibre-imepe'
```

And then execute:

    $ bundle install

## Usage

Go to integrations Menu and turn on the MesParcelles integration with siret_number present and a harest_year.

## Development

### API Credentials

You have to grab a token to access with ID/PASS to test the API. Ask dev@ekylibre.com

### Adding method to API

Look at https://poitou-charentes.test.mesparcelles.fr/api/apidocs/#/ and check what method you need

Example : /geom/ilot/{idilot} if we want the shape of an "ilot"

```json
{
  "geom_ilot": {
    "identifiant": 1708221,
    "geom": {
      "type": "Polygon",
      "coordinates": [
        [
          [
            921589.327,
            6461854.337
          ],
          [
            921524.511,
            6461952.524
          ],
          [
            921529.033,
            6462011.318
          ],
          [
            921530.286,
            6462027.609
          ],
          [
            921690.723,
            6462148.899
          ],
          [
            921700.677,
            6462132.199
          ],
          [
            921720.909,
            6462098.255
          ],
          [
            921755.128,
            6462036.324
          ],
          [
            921772.899,
            6461985.393
          ],
          [
            921589.327,
            6461854.337
          ]
        ]
      ]
    },
    "parcelles": [
      {
        "geom_parcelle": {
          "identifiant": 2706014,
          "geom": {
            "type": "Polygon",
            "coordinates": [
              [
                [
                  921589.327,
                  6461854.337
                ],
                [
                  921524.511,
                  6461952.524
                ],
                [
                  921529.033,
                  6462011.318
                ],
                [
                  921700.677,
                  6462132.199
                ],
                [
                  921720.909,
                  6462098.255
                ],
                [
                  921755.128,
                  6462036.324
                ],
                [
                  921772.899,
                  6461985.393
                ],
                [
                  921589.327,
                  6461854.337
                ]
              ]
            ]
          }
        }
      },
      {
        "geom_parcelle": {
          "identifiant": 2706015,
          "geom": {
            "type": "Polygon",
            "coordinates": [
              [
                [
                  921700.677,
                  6462132.199
                ],
                [
                  921529.033,
                  6462011.318
                ],
                [
                  921530.286,
                  6462027.609
                ],
                [
                  921690.723,
                  6462148.899
                ],
                [
                  921700.677,
                  6462132.199
                ]
              ]
            ]
          }
        }
      }
    ]
  }
}
```

then add a method in app/integrations/<<integration_name>>/<<integration_name>>_integration.rb

Example for get ilots geom

```ruby
# get ilots geom
def get_cultivable_zone_geom_from_id(cultivable_zone_id)
  # get integration object for authentication
  integration = fetch
  username = integration.parameters['username']
  password = integration.parameters['password']
  # call API corresponding to
  get_json(url("geom/ilot/#{cultivable_zone_id}"), headers(username, password) ) do |r|
    r.success do
      resp = JSON.parse(r.body)
      # then we grab the geom
      geom_cz = resp['geom_ilot']['geom']
      # return geom.to_json or ''
      if geom_cz.blank?
        ''
      else
        geom_cz.to_json
      end
    end
  end
end
```

### Adding method to job

### Data exchange informations for user

In order to show to the user what kind of data are going to be exchange, you have to write the data perimeter in locales/fra.yml and other locales if needed.

Example for incomming data updating land_parcels and cultivable_zones and no outgoing data.

```yml
  mes_parcelles_incoming_data_exchange: "Parcelles (Parcelles PAC) et Zones cultivables (Ilots PAC)"
  mes_parcelles_outgoing_data_exchange: "Aucune donnée sortante"
```

## Contributing
