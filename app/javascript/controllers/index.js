// Import and register all your controllers from the importmap via controllers/**/*_controller
import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
import AlertModalController from "controllers/alert_modal_controller"
import ColumnSelectionController from "controllers/column_selection_controller"
import ConnectorTableInputsController from "controllers/connector_table_inputs_controller"
import ConnectorWizardController from "controllers/connector_wizard_controller"
import DestinationSelectorController from "controllers/destination_selector_controller"
import DisclosureController from "controllers/disclosure_controller"
import FileConnectorModeController from "controllers/file_connector_mode_controller"
import PipelineFormController from "controllers/pipeline_form_controller"
import PowerbiConfigController from "controllers/powerbi_config_controller"
import RowLimitVisibilityController from "controllers/row_limit_visibility_controller"
import SidebarController from "controllers/sidebar_controller"
import SourceSelectorController from "controllers/source_selector_controller"
import TablePreviewController from "controllers/table_preview_controller"
import TestConnectionController from "controllers/test_connection_controller"
import ChartController from "controllers/chart_controller"
import VisualQueryBuilderController from "controllers/visual_query_builder_controller"
import ColumnSelectorController from "controllers/column_selector_controller"
import JoinBuilderController from "controllers/join_builder_controller"
import AggregationBuilderController from "controllers/aggregation_builder_controller"
import CollapsibleSectionController from "controllers/collapsible_section_controller"

// Manually register controllers
application.register("alert-modal", AlertModalController)
application.register("chart", ChartController)
application.register("column-selection", ColumnSelectionController)
application.register("connector-table-inputs", ConnectorTableInputsController)
application.register("connector-wizard", ConnectorWizardController)
application.register("destination-selector", DestinationSelectorController)
application.register("disclosure", DisclosureController)
application.register("file-connector-mode", FileConnectorModeController)
application.register("pipeline-form", PipelineFormController)
application.register("powerbi-config", PowerbiConfigController)
application.register("row-limit-visibility", RowLimitVisibilityController)
application.register("sidebar", SidebarController)
application.register("source-selector", SourceSelectorController)
application.register("table-preview", TablePreviewController)
application.register("test-connection", TestConnectionController)
// Alice VQB controllers
application.register("visual-query-builder", VisualQueryBuilderController)
application.register("column-selector", ColumnSelectorController)
application.register("join-builder", JoinBuilderController)
application.register("aggregation-builder", AggregationBuilderController)
application.register("collapsible-section", CollapsibleSectionController)

eagerLoadControllersFrom("controllers", application)
