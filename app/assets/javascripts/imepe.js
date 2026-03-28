// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or any plugin's vendor/assets/javascripts directory can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// compiled file.
//
// Read Sprockets README (https://github.com/rails/sprockets#sprockets-directives) for details
// about supported directives.
//
(function (E) {
    function handleSelectImepeUrl() {
      if (document.querySelector("#integration_nature[value='mes_parcelles']") != undefined) {
        const element = document.querySelector('#integration_parameters_base_url')
        let new_element = document.createElement('select')
        new_element.setAttribute("id", "integration_parameters_base_url")
        new_element.setAttribute("name", "integration[parameters][base_url]")
        new_element.innerHTML = '<option value="normandie">Normandie</option>' + '<option value="pdl">Pays de loire</option>' + '<option value="rhone-alpes">Rhônes alpes</option>'

        element.replaceWith(new_element);
      }
    }

    E.onDomReady(function () {
      handleSelectImepeUrl()
    })

})(ekylibre)
