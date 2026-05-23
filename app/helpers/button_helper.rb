module ButtonHelper
  # Renders a styled button
  #
  # @param text [String] Button text
  # @param variant [Symbol] Button style (:primary, :secondary, :danger, :success, :outline)
  # @param size [Symbol] Button size (:sm, :md, :lg)
  # @param options [Hash] Additional HTML options
  #
  # @example
  #   <%= button_tag "Save", variant: :primary, size: :lg %>
  #   <%= button_tag "Cancel", variant: :secondary, class: "ml-2" %>
  #
  def alice_button(text, variant: :primary, size: :md, **options)
    base_classes = "inline-flex items-center justify-center font-semibold rounded-lg transition-colors focus:outline-none focus:ring-2 focus:ring-offset-2"

    # Size classes
    size_classes = case size
    when :sm
      "px-3 py-1.5 text-sm"
    when :lg
      "px-6 py-3 text-lg"
    else # :md
      "px-4 py-2 text-base"
    end

    # Variant classes
    variant_classes = case variant
    when :primary
      "bg-primary text-white hover:bg-primary-dark focus:ring-primary"
    when :secondary
      "bg-gray-200 text-gray-900 hover:bg-gray-300 focus:ring-gray-500"
    when :danger
      "bg-danger text-white hover:bg-red-700 focus:ring-red-500"
    when :success
      "bg-success text-white hover:bg-green-700 focus:ring-green-500"
    when :outline
      "bg-white text-primary border-2 border-primary hover:bg-primary hover:text-white focus:ring-primary"
    else
      "bg-primary text-white hover:bg-primary-dark focus:ring-primary"
    end

    # Merge classes
    classes = [ base_classes, size_classes, variant_classes, options[:class] ].compact.join(" ")
    options = options.except(:class).merge(class: classes)

    content_tag(:button, text, **options)
  end

  # Renders a link styled as a button
  def alice_link_button(text, path, variant: :primary, size: :md, **options)
    base_classes = "inline-flex items-center justify-center font-semibold rounded-lg transition-colors focus:outline-none focus:ring-2 focus:ring-offset-2 no-underline"

    size_classes = case size
    when :sm
      "px-3 py-1.5 text-sm"
    when :lg
      "px-6 py-3 text-lg"
    else # :md
      "px-4 py-2 text-base"
    end

    variant_classes = case variant
    when :primary
      "bg-primary text-white hover:bg-primary-dark focus:ring-primary"
    when :secondary
      "bg-gray-200 text-gray-900 hover:bg-gray-300 focus:ring-gray-500"
    when :danger
      "bg-danger text-white hover:bg-red-700 focus:ring-red-500"
    when :success
      "bg-success text-white hover:bg-green-700 focus:ring-green-500"
    when :outline
      "bg-white text-primary border-2 border-primary hover:bg-primary hover:text-white focus:ring-primary"
    else
      "bg-primary text-white hover:bg-primary-dark focus:ring-primary"
    end

    classes = [ base_classes, size_classes, variant_classes, options[:class] ].compact.join(" ")
    options = options.except(:class).merge(class: classes)

    link_to text, path, **options
  end
end
