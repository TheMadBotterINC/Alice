module BreadcrumbHelper
  # Renders a breadcrumb navigation
  #
  # @example
  #   <%= alice_breadcrumbs do |b| %>
  #     <%= b.item "Home", root_path %>
  #     <%= b.item "Pipelines", pipelines_path %>
  #     <%= b.item "Pipeline #123" %>
  #   <% end %>
  #
  def alice_breadcrumbs(**options, &block)
    container_classes = "flex items-center space-x-2 text-sm text-gray-500 mb-4 #{options[:class]}".strip

    content_tag(:nav, class: container_classes, aria: { label: "Breadcrumb" }) do
      content_tag(:ol, class: "flex items-center space-x-2") do
        breadcrumb_builder = Struct.new(:context, :items) do
          def item(label, path = nil, icon: nil)
            items << { label: label, path: path, icon: icon }
            nil # Don't output anything directly
          end

          def render
            items.each_with_index do |item, index|
              is_last = index == items.length - 1

              context.concat context.content_tag(:li, class: "flex items-center") do
                # Add separator before all items except first
                if index > 0
                  context.concat context.content_tag(:svg, class: "flex-shrink-0 h-5 w-5 text-gray-400 mr-2", fill: "currentColor", viewBox: "0 0 20 20") do
                    '<path fill-rule="evenodd" d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clip-rule="evenodd" />'.html_safe
                  end
                end

                # Render item
                if is_last
                  # Current page - not a link
                  context.concat context.content_tag(:span, class: "font-medium text-gray-700", aria: { current: "page" }) do
                    if item[:icon]
                      context.concat context.content_tag(:span, item[:icon].html_safe, class: "mr-1")
                    end
                    context.concat item[:label]
                  end
                else
                  # Link to previous pages
                  context.concat context.link_to(item[:path], class: "hover:text-gray-700 transition") do
                    if item[:icon]
                      context.concat context.content_tag(:span, item[:icon].html_safe, class: "mr-1")
                    end
                    context.concat item[:label]
                  end
                end
              end
            end
          end
        end

        builder = breadcrumb_builder.new(self, [])
        yield builder
        builder.render
      end
    end
  end
end
