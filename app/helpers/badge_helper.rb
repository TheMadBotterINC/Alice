module BadgeHelper
  # Renders a styled badge for status indicators
  #
  # @param text [String] Badge text
  # @param variant [Symbol] Badge color (:primary, :success, :danger, :warning, :info, :gray)
  # @param size [Symbol] Badge size (:sm, :md, :lg)
  # @param options [Hash] Additional HTML options
  #
  # @example
  #   <%= alice_badge "Active", variant: :success %>
  #   <%= alice_badge "Failed", variant: :danger, size: :lg %>
  #   <%= alice_badge user.role.humanize, variant: :primary %>
  #
  def alice_badge(text, variant: :gray, size: :md, **options)
    base_classes = "inline-flex items-center font-medium rounded-full"

    # Size classes
    size_classes = case size
    when :sm
      "px-2 py-0.5 text-xs"
    when :lg
      "px-4 py-1.5 text-base"
    else # :md
      "px-3 py-1 text-sm"
    end

    # Variant classes
    variant_classes = case variant
    when :primary
      "bg-primary text-white"
    when :success
      "bg-success text-white"
    when :danger
      "bg-danger text-white"
    when :warning
      "bg-warning text-gray-900"
    when :info
      "bg-info text-white"
    when :gray
      "bg-gray-200 text-gray-800"
    else
      "bg-gray-200 text-gray-800"
    end

    # Merge classes
    classes = [ base_classes, size_classes, variant_classes, options[:class] ].compact.join(" ")
    options = options.except(:class).merge(class: classes)

    content_tag(:span, text, **options)
  end

  # Renders a badge with a dot indicator
  def alice_status_badge(text, variant: :gray, **options)
    content_tag(:span, class: "inline-flex items-center #{options[:class]}") do
      concat content_tag(:span, "", class: "w-2 h-2 rounded-full mr-2 #{dot_color_for_variant(variant)}")
      concat alice_badge(text, variant: variant, **options.except(:class))
    end
  end

  private

  def dot_color_for_variant(variant)
    case variant
    when :primary then "bg-primary"
    when :success then "bg-success"
    when :danger then "bg-danger"
    when :warning then "bg-warning"
    when :info then "bg-info"
    else "bg-gray-400"
    end
  end
end
