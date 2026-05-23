module FormHelper
  # Renders a form group with label, input, and error messages
  #
  # @example
  #   <%= alice_form_group form, :email, type: :email, required: true %>
  #   <%= alice_form_group form, :description, type: :textarea, rows: 4 %>
  #   <%= alice_form_group form, :role, type: :select, options: User.roles.keys %>
  #
  def alice_form_group(form, field, type: :text, label: nil, help_text: nil, required: false, **options)
    model = form.object
    label_text = label || field.to_s.humanize
    errors = model.errors[field] if model.respond_to?(:errors)
    has_error = errors.present?

    content_tag(:div, class: "mb-4") do
      concat form_label(label_text, field, required, has_error)
      concat form_input(form, field, type, has_error, required, options)
      concat form_help_text(help_text) if help_text
      concat form_error_messages(errors) if has_error
    end
  end

  private

  def form_label(text, field, required, has_error)
    label_classes = "block text-sm font-medium mb-2 #{has_error ? 'text-danger' : 'text-gray-700'}"
    content_tag(:label, for: field, class: label_classes) do
      concat text
      concat content_tag(:span, " *", class: "text-danger") if required
    end
  end

  def form_input(form, field, type, has_error, required, options)
    base_classes = "w-full px-4 py-2 border rounded-lg transition focus:outline-none focus:ring-2"

    if has_error
      input_classes = "#{base_classes} border-danger focus:ring-danger focus:border-danger"
    else
      input_classes = "#{base_classes} border-gray-300 focus:ring-primary focus:border-transparent"
    end

    options = options.merge(class: "#{input_classes} #{options[:class]}".strip, required: required)

    case type
    when :textarea
      form.text_area(field, **options)
    when :select
      select_options = options.delete(:options) || []
      form.select(field, select_options, { include_blank: options.delete(:include_blank) }, **options)
    when :email
      form.email_field(field, **options)
    when :password
      form.password_field(field, **options)
    when :number
      form.number_field(field, **options)
    when :date
      form.date_field(field, **options)
    when :datetime
      form.datetime_field(field, **options)
    when :checkbox
      content_tag(:div, class: "flex items-center") do
        concat form.check_box(field, class: "h-4 w-4 text-primary focus:ring-primary border-gray-300 rounded")
        concat content_tag(:span, options[:label] || field.to_s.humanize, class: "ml-2 text-sm text-gray-700")
      end
    else
      form.text_field(field, **options)
    end
  end

  def form_help_text(text)
    content_tag(:p, text, class: "mt-1 text-sm text-gray-500")
  end

  def form_error_messages(errors)
    return if errors.blank?

    content_tag(:div, class: "mt-1") do
      errors.each do |error|
        concat content_tag(:p, error, class: "text-sm text-danger flex items-center")
      end
    end
  end
end
