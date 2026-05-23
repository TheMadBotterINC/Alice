# Alice UI Components & Brand Guidelines

## Brand Colors

### Primary Colors
- **Primary Dark** (`bg-primary-dark`, `text-primary-dark`): #1a134a - Deep navy, used for headers and important text
- **Primary** (`bg-primary`, `text-primary`): #27a2d6 - Alice blue, main brand color
- **Primary Light** (`bg-primary-light`, `text-primary-light`): #44c8f5 - Light blue for highlights
- **Primary Pale** (`bg-primary-pale`, `text-primary-pale`): #ecebd8 - Cream background

### Semantic Colors
- **Success** (`bg-success`, `text-success`): #26a74a - Green for success states
- **Danger** (`bg-danger`, `text-danger`): #f04d3f - Red for errors/destructive actions
- **Warning** (`bg-warning`, `text-warning`): #ffc107 - Yellow for warnings
- **Info** (`bg-info`, `text-info`): #17a2b9 - Teal for informational elements

## Reusable Components

### Buttons

#### Primary Button
```erb
<%= link_to "Button Text", path, 
    class: "inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-primary hover:bg-primary-dark focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary" %>
```

#### Secondary Button
```erb
<%= link_to "Button Text", path, 
    class: "inline-flex items-center px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary" %>
```

#### Destructive Button
```erb
<%= button_to "Delete", path, method: :delete, 
    class: "inline-flex items-center px-4 py-2 border border-red-300 rounded-md shadow-sm text-sm font-medium text-red-700 bg-white hover:bg-red-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500" %>
```

### Status Badges

```erb
<% badge_class = case status
                 when "succeeded", "active", "connected" then "bg-green-100 text-green-800"
                 when "failed", "error" then "bg-red-100 text-red-800"
                 when "running", "pending" then "bg-blue-100 text-blue-800"
                 when "draft", "idle" then "bg-yellow-100 text-yellow-800"
                 else "bg-gray-100 text-gray-800"
                 end %>
<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium <%= badge_class %>">
  <%= status.titleize %>
</span>
```

### Cards

```erb
<div class="bg-white rounded-lg shadow overflow-hidden">
  <div class="px-6 py-4 border-b border-gray-200">
    <h2 class="text-lg font-semibold text-gray-900">Card Title</h2>
  </div>
  <div class="px-6 py-4">
    <!-- Card content -->
  </div>
</div>
```

### Stats Cards (Dashboard)

```erb
<div class="bg-white rounded-lg shadow hover:shadow-lg transition-shadow p-6">
  <div class="flex items-center">
    <div class="flex-shrink-0">
      <svg class="h-10 w-10 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <!-- Icon path -->
      </svg>
    </div>
    <div class="ml-4">
      <p class="text-sm font-medium text-gray-500">Label</p>
      <p class="text-3xl font-bold text-primary-dark">Value</p>
    </div>
  </div>
</div>
```

### Flash Messages

Flash messages are automatically styled in `application.html.erb`:
- **Notice** (success): Green background (`bg-success`)
- **Alert** (error): Red background (`bg-danger`)
- **Warning**: Yellow background (`bg-warning`)
- **Info**: Teal background (`bg-info`)

### Navigation

Active navigation items use:
- `bg-primary text-white` for active state
- `text-gray-700 hover:bg-gray-100` for inactive state

### Forms

#### Form Input
```erb
<div class="mb-4">
  <%= f.label :field_name, class: "block text-sm font-medium text-gray-700 mb-2" %>
  <%= f.text_field :field_name, 
      class: "w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary focus:border-transparent" %>
</div>
```

#### Form Validation Errors
```erb
<% if @model.errors[:field_name].any? %>
  <p class="mt-1 text-sm text-red-600">
    <%= @model.errors[:field_name].first %>
  </p>
<% end %>
```

## Typography

- **Headings**: Use `text-gray-900` and `font-bold` or `font-semibold`
- **Body Text**: Use `text-gray-700` or `text-gray-600`
- **Secondary Text**: Use `text-gray-500` or `text-gray-400`
- **Links**: Use `text-primary hover:text-primary-dark`

## Layout Patterns

### Two-Column Layout (Main + Sidebar)
```erb
<div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
  <div class="lg:col-span-2">
    <!-- Main content (2/3 width) -->
  </div>
  <div class="lg:col-span-1">
    <!-- Sidebar (1/3 width) -->
  </div>
</div>
```

### Four-Column Stats Grid
```erb
<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
  <!-- Four stat cards -->
</div>
```

## Icons

Using Heroicons (outline style) consistently throughout the app. Common icons:
- **Home**: `M3 12l2-2m0 0l7-7...`
- **Lightning Bolt** (Pipelines): `M13 10V3L4 14h7v7l9-11h-7z`
- **Terminal** (Connectors): `M8 9l3 3-3 3m5 0h3...`
- **Database** (Datasets): `M4 7v10c0 2.21 3.582 4 8 4...`

## Best Practices

1. **Always use brand colors** instead of generic Tailwind colors
2. **Maintain consistent spacing** using Tailwind's spacing scale
3. **Use shadow classes** for depth: `shadow`, `shadow-lg`, `hover:shadow-lg`
4. **Add transitions** for interactive elements: `transition-colors`, `transition-shadow`
5. **Ensure accessibility**: Include proper ARIA labels and focus states
6. **Mobile-first**: Use responsive classes (`sm:`, `md:`, `lg:`)
