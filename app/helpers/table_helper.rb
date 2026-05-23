module TableHelper
  # Renders a styled table container
  #
  # @example
  #   <%= alice_table do %>
  #     <thead>
  #       <%= alice_table_header_row do %>
  #         <%= alice_table_header "Name" %>
  #         <%= alice_table_header "Status" %>
  #         <%= alice_table_header "Actions", class: "text-right" %>
  #       <% end %>
  #     </thead>
  #     <tbody>
  #       <%= alice_table_row do %>
  #         <%= alice_table_cell "Pipeline 1" %>
  #         <%= alice_table_cell alice_badge("Active", variant: :success) %>
  #         <%= alice_table_cell link_to("View", "#"), class: "text-right" %>
  #       <% end %>
  #     </tbody>
  #   <% end %>
  #
  def alice_table(striped: true, hoverable: true, **options, &block)
    base_classes = "min-w-full divide-y divide-gray-200"
    table_classes = [
      base_classes,
      options[:class]
    ].compact.join(" ")

    container_classes = "overflow-x-auto bg-white rounded-lg shadow"

    content_tag(:div, class: container_classes) do
      content_tag(:table, class: table_classes, **options.except(:class), &block)
    end
  end

  def alice_table_header_row(**options, &block)
    classes = "bg-gray-50 #{options[:class]}".strip
    content_tag(:tr, class: classes, **options.except(:class), &block)
  end

  def alice_table_header(text = nil, sortable: false, sort_path: nil, **options, &block)
    base_classes = "px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
    classes = "#{base_classes} #{options[:class]}".strip

    content = if block_given?
      capture(&block)
    else
      text
    end

    if sortable && sort_path
      content_tag(:th, scope: "col", class: classes, **options.except(:class)) do
        link_to sort_path, class: "group inline-flex items-center hover:text-gray-700" do
          concat content
          concat content_tag(:span, class: "ml-2 flex-none rounded text-gray-400") do
            # Sort icon
            '<svg class="h-4 w-4" fill="currentColor" viewBox="0 0 20 20">
              <path d="M5 12a1 1 0 102 0V6.414l1.293 1.293a1 1 0 001.414-1.414l-3-3a1 1 0 00-1.414 0l-3 3a1 1 0 001.414 1.414L5 6.414V12zM15 8a1 1 0 10-2 0v5.586l-1.293-1.293a1 1 0 00-1.414 1.414l3 3a1 1 0 001.414 0l3-3a1 1 0 00-1.414-1.414L15 13.586V8z" />
            </svg>'.html_safe
          end
        end
      end
    else
      content_tag(:th, content, scope: "col", class: classes, **options.except(:class))
    end
  end

  def alice_table_row(hoverable: true, **options, &block)
    base_classes = hoverable ? "hover:bg-gray-50 transition" : ""
    classes = "#{base_classes} #{options[:class]}".strip
    content_tag(:tr, class: classes, **options.except(:class), &block)
  end

  def alice_table_cell(content = nil, **options, &block)
    base_classes = "px-6 py-4 whitespace-nowrap text-sm text-gray-900"
    classes = "#{base_classes} #{options[:class]}".strip

    cell_content = block_given? ? capture(&block) : content
    content_tag(:td, cell_content, class: classes, **options.except(:class))
  end

  # Empty state for tables
  def alice_table_empty_state(message: "No items found", colspan: 5)
    content_tag(:tr) do
      content_tag(:td, colspan: colspan, class: "px-6 py-12 text-center") do
        content_tag(:div, class: "text-gray-500") do
          concat content_tag(:svg, class: "mx-auto h-12 w-12 text-gray-400 mb-4", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do
            '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4" />'.html_safe
          end
          concat content_tag(:p, message, class: "text-sm font-medium text-gray-900")
        end
      end
    end
  end
end
