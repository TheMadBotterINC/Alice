# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin_all_from "app/javascript/helpers", under: "helpers"

# Explicitly pin controllers
pin "controllers/alert_modal_controller"
pin "controllers/chart_controller"
pin "controllers/column_selection_controller"
pin "controllers/connector_table_inputs_controller"
pin "controllers/connector_wizard_controller"
pin "controllers/destination_selector_controller"
pin "controllers/disclosure_controller"
pin "controllers/file_connector_mode_controller"
pin "controllers/row_limit_visibility_controller"
pin "controllers/sidebar_controller"
pin "controllers/source_selector_controller"
pin "controllers/table_preview_controller"
pin "controllers/test_connection_controller"
# Alice VQB controllers
pin "controllers/visual_query_builder_controller"
pin "controllers/column_selector_controller"
pin "controllers/join_builder_controller"
pin "controllers/aggregation_builder_controller"
