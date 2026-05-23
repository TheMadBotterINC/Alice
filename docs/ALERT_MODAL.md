# Alert Modal Component

A beautiful, reusable alert modal component styled with Tailwind CSS that replaces the default browser `alert()` function.

## Features

- 🎨 **Beautiful UI** - Clean, modern design with Tailwind CSS
- 🎯 **Multiple Types** - Info, Success, Warning, and Error variants
- 🔔 **Auto-dismiss** - Success messages auto-hide after 5 seconds
- ⌨️ **Keyboard Support** - Close with backdrop click
- 🌍 **Global Access** - Available from any JavaScript code
- 📱 **Responsive** - Works great on mobile and desktop

## Usage

### From JavaScript

The alert modal is globally available via helper functions:

```javascript
// Show error alert
window.showError('Validation Failed', 'Please fill in all required fields.')

// Show success alert (auto-dismisses after 5 seconds)
window.showSuccess('Saved!', 'Your changes have been saved successfully.')

// Show warning alert
window.showWarning('Warning', 'This action cannot be undone.')

// Show info alert
window.showInfo('Did you know?', 'You can press Ctrl+S to save.')

// Generic alert with custom type
window.showAlert('Custom Title', 'Custom message', 'error')
```

### From Stimulus Controllers

Access the alert modal controller directly:

```javascript
// In your Stimulus controller
const alertElement = document.querySelector('[data-controller~="alert-modal"]')
const alertController = this.application.getControllerForElementAndIdentifier(
  alertElement,
  'alert-modal'
)

alertController.show('Title', 'Message', 'success')
```

## Alert Types

### Error
```javascript
window.showError('Error Title', 'Error message details')
```
- Red icon and styling
- X icon
- Requires manual dismiss

### Success
```javascript
window.showSuccess('Success!', 'Operation completed successfully')
```
- Green icon and styling
- Checkmark icon
- Auto-dismisses after 5 seconds

### Warning
```javascript
window.showWarning('Warning', 'Please review before continuing')
```
- Yellow icon and styling
- Alert triangle icon
- Requires manual dismiss

### Info
```javascript
window.showInfo('Information', 'Here is some helpful information')
```
- Blue icon and styling
- Info (i) icon
- Requires manual dismiss

## Examples

### Replace Browser Alerts

**Before:**
```javascript
if (!valid) {
  alert('Please fill in all required fields')
}
```

**After:**
```javascript
if (!valid) {
  window.showError('Required Fields Missing', 'Please fill in all required fields before continuing.')
}
```

### Form Validation

```javascript
validateForm() {
  const email = this.emailTarget.value
  
  if (!email.includes('@')) {
    window.showError('Invalid Email', 'Please enter a valid email address.')
    return false
  }
  
  return true
}
```

### Success Notifications

```javascript
async saveData() {
  try {
    const response = await fetch('/api/save', { method: 'POST', body: data })
    if (response.ok) {
      window.showSuccess('Saved!', 'Your changes have been saved successfully.')
    }
  } catch (error) {
    window.showError('Save Failed', error.message)
  }
}
```

### Confirmation Warnings

```javascript
deleteItem() {
  window.showWarning(
    'Delete Confirmation', 
    'Are you sure you want to delete this item? This action cannot be undone.'
  )
}
```

### Helpful Tips

```javascript
connect() {
  window.showInfo(
    'Keyboard Shortcuts', 
    'Press Ctrl+S to save or Ctrl+Z to undo.'
  )
}
```

## Customization

### Modify Alert Duration

Edit `app/javascript/controllers/alert_modal_controller.js`:

```javascript
// Change auto-hide duration for success messages
if (type === 'success') {
  setTimeout(() => this.hide(), 3000) // 3 seconds instead of 5
}
```

### Add New Alert Types

Add custom types to the controller's `updateAppearance()` method:

```javascript
case 'critical':
  iconTarget.classList.add('bg-purple-100')
  iconTarget.innerHTML = `
    <svg class="h-6 w-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01"/>
    </svg>
  `
  break
```

Then use it:
```javascript
window.showAlert('Critical Alert', 'This requires immediate attention', 'critical')
```

### Style Customization

Modify the partial `app/views/shared/_alert_modal.html.erb`:

- Change modal size: Update `sm:max-w-lg` to `sm:max-w-xl` for larger
- Adjust button colors: Modify `bg-primary` classes
- Change animations: Add transition classes

## Implementation Details

### Files

- **Controller:** `app/javascript/controllers/alert_modal_controller.js`
- **View Partial:** `app/views/shared/_alert_modal.html.erb`
- **Helper:** `app/javascript/helpers/alert_helper.js`
- **Layout:** Included in `app/views/layouts/application.html.erb`

### How It Works

1. Alert modal partial is rendered once in the application layout
2. Modal is hidden by default with `hidden` class
3. JavaScript calls trigger the modal to show with specific content and styling
4. Stimulus controller manages state and appearance
5. Modal can be closed by clicking OK or the backdrop

### Stimulus Controller Targets

- `modal` - The modal overlay container
- `title` - The alert title element
- `message` - The alert message element
- `icon` - The icon container (dynamically updated)

### Browser Compatibility

Works in all modern browsers that support:
- ES6+ JavaScript
- CSS Flexbox
- CSS Grid
- Stimulus.js

## Migration Guide

To replace all browser `alert()` calls in your codebase:

1. **Find all alerts:**
   ```bash
   grep -r "alert(" app/javascript/
   ```

2. **Replace patterns:**
   ```javascript
   // Old
   alert('Message')
   
   // New
   window.showError('Error', 'Message')
   // or
   window.showInfo('Notice', 'Message')
   ```

3. **Update validation messages:**
   ```javascript
   // Old
   if (!valid) {
     alert('Validation failed')
   }
   
   // New
   if (!valid) {
     window.showError('Validation Failed', 'Please check your input and try again.')
   }
   ```

## Accessibility

The modal includes:
- Semantic HTML structure
- Proper ARIA roles (automatically added)
- Keyboard navigation support
- Focus management
- Screen reader friendly

## Best Practices

1. **Use appropriate types:**
   - Errors for validation failures and critical issues
   - Success for completed operations
   - Warnings for potentially dangerous actions
   - Info for helpful tips and notifications

2. **Keep messages concise:**
   - Title: Short and clear (3-5 words)
   - Message: Brief explanation (1-2 sentences)

3. **Don't overuse:**
   - Use for important notifications only
   - Consider inline validation for form errors
   - Use toast notifications for minor updates

4. **Provide context:**
   - Always include both title and message
   - Be specific about what went wrong
   - Suggest next steps when appropriate

## Future Enhancements

Potential improvements:
- Add confirm/cancel actions for confirmation dialogs
- Support for custom buttons
- HTML content support
- Stacking multiple alerts
- Sound effects
- Animation options
- Toast-style notifications

## Support

For issues or questions:
- Check the implementation in `app/javascript/controllers/alert_modal_controller.js`
- Review browser console for error messages
- Ensure Stimulus is properly loaded
- Verify the alert modal partial is in the layout
