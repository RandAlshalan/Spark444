# Utility Classes for Enhanced Responsiveness and Usability

This directory contains utility classes to improve app responsiveness and user experience.

## Files

### 1. `page_transitions.dart`
Custom page transitions for smooth navigation throughout the app.

**Available Transitions:**
- `SmoothPageRoute` - Default fade + slide (300ms) - Use for most navigations
- `FadePageRoute` - Subtle fade only (250ms) - Use for quick transitions
- `ScalePageRoute` - Scale + fade (350ms) - Use for dialog-like pages
- `SlideUpPageRoute` - Slide from bottom (350ms) - Use for modal pages
- `NoTransitionRoute` - Instant (0ms) - Use for tab switches

**Usage Example:**
```dart
// Navigate with smooth transition
Navigator.push(
  context,
  SmoothPageRoute(page: MyPage()),
);

// Or use extension methods
context.pushSmooth(MyPage());
context.pushFade(MyPage());
context.pushScale(MyPage());
```

### 2. `responsive_utils.dart`
Comprehensive utilities for responsive design and reusable UI components.

**Classes:**

#### ResponsiveUtils
Static methods for responsive sizing and spacing.

```dart
// Get responsive padding
EdgeInsets padding = ResponsiveUtils.getResponsivePadding(context);

// Get responsive font size
double fontSize = ResponsiveUtils.getResponsiveFontSize(context, 16);

// Check if tablet
bool isTablet = ResponsiveUtils.isTablet(context);

// Get responsive spacing
double spacing = ResponsiveUtils.getSpacing(context, 16);

// Get responsive icon size
double iconSize = ResponsiveUtils.getIconSize(context, 24);
```

#### ResponsiveButton
Button with proper touch targets (48dp minimum) and loading states.

```dart
ResponsiveButton(
  text: 'Submit',
  icon: Icons.send,
  onPressed: () {},
  isLoading: false,
  backgroundColor: Colors.blue,
)
```

#### EmptyStateWidget
Consistent empty state UI across the app.

```dart
EmptyStateWidget(
  icon: Icons.inbox,
  title: 'No opportunities found',
  subtitle: 'Try adjusting your filters',
  action: ResponsiveButton(
    text: 'Clear Filters',
    onPressed: () {},
  ),
)
```

#### ErrorStateWidget
Error state with retry option.

```dart
ErrorStateWidget(
  message: 'Failed to load data',
  onRetry: () => _fetchData(),
)
```

#### LoadingOverlay
Show loading indicator over content.

```dart
LoadingOverlay(
  isLoading: _isProcessing,
  loadingText: 'Processing...',
  child: MyContent(),
)
```

#### ResponsiveTextField
Improved text field with better UX.

```dart
ResponsiveTextField(
  label: 'Email',
  hint: 'Enter your email',
  prefixIcon: Icons.email,
  keyboardType: TextInputType.emailAddress,
  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
)
```

#### SnackBarHelper
Consistent messaging across the app.

```dart
// Success message
SnackBarHelper.showSuccess(context, 'Saved successfully!');

// Error message
SnackBarHelper.showError(context, 'Failed to save');

// Info message
SnackBarHelper.showInfo(context, 'Uploading...');
```

### 3. `keyboard_utils.dart`
Utilities for keyboard management and form handling.

**Classes:**

#### KeyboardUtils
Static methods for keyboard control.

```dart
// Hide keyboard
KeyboardUtils.hideKeyboard(context);

// Show keyboard
KeyboardUtils.showKeyboard(context, myFocusNode);

// Check if keyboard is visible
bool isVisible = KeyboardUtils.isKeyboardVisible(context);
```

#### DismissKeyboard
Widget that dismisses keyboard when tapping outside.

```dart
DismissKeyboard(
  child: MyForm(),
)
```

#### ResponsiveForm
Form with automatic keyboard management.

```dart
ResponsiveForm(
  formKey: _formKey,
  dismissKeyboardOnTap: true,
  children: [
    ResponsiveTextField(label: 'Name'),
    ResponsiveTextField(label: 'Email'),
    ResponsiveButton(text: 'Submit'),
  ],
)
```

## Best Practices

### 1. Touch Targets
- All interactive elements should be at least 48x48 dp
- Use `ResponsiveButton` which automatically ensures minimum size
- Add `splashRadius: 20` to IconButtons for better touch feedback

### 2. Responsive Sizing
- Always use `ResponsiveUtils.getResponsiveFontSize()` for dynamic text
- Use `ResponsiveUtils.getResponsivePadding()` for consistent spacing
- Check `ResponsiveUtils.isTablet()` for tablet-specific layouts

### 3. Loading States
- Always show loading indicators for async operations
- Use `LoadingOverlay` for inline operations
- Use `isLoading` parameter in `ResponsiveButton` for submit buttons

### 4. Error Handling
- Use `ErrorStateWidget` for full-screen errors
- Use `SnackBarHelper.showError()` for inline errors
- Always provide retry options when appropriate

### 5. Empty States
- Use `EmptyStateWidget` consistently
- Provide helpful messages and actions
- Guide users on what to do next

### 6. Keyboard Management
- Wrap forms in `DismissKeyboard` or `ResponsiveForm`
- Call `KeyboardUtils.hideKeyboard()` before navigation
- Use proper `TextInputAction` for better UX

### 7. Page Transitions
- Use `SmoothPageRoute` for most navigations
- Use `NoTransitionRoute` for tab switches
- Use `FadePageRoute` for subtle transitions

## Migration Guide

### Before:
```dart
// Old navigation
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => MyPage()),
);

// Old button
ElevatedButton(
  onPressed: () {},
  child: Text('Submit'),
)

// Old empty state
Center(
  child: Text('No data'),
)
```

### After:
```dart
// New navigation
Navigator.push(
  context,
  SmoothPageRoute(page: MyPage()),
);

// New button
ResponsiveButton(
  text: 'Submit',
  onPressed: () {},
  isLoading: _isSubmitting,
)

// New empty state
EmptyStateWidget(
  icon: Icons.inbox,
  title: 'No data found',
  subtitle: 'Try refreshing',
)
```

## Performance Tips

1. **Pull-to-Refresh**: Added to main pages for easy data refresh
2. **Loading States**: Prevent multiple taps during async operations
3. **Keyboard Dismissal**: Improves form UX and prevents layout issues
4. **Smooth Transitions**: Better perceived performance with animations
5. **Touch Targets**: Reduces user frustration and errors

## Accessibility

All components follow Material Design guidelines:
- Minimum touch targets (48dp)
- Proper contrast ratios
- Semantic labels (tooltips, aria labels)
- Keyboard navigation support
- Screen reader friendly

## Future Enhancements

- [ ] Add haptic feedback for button presses
- [ ] Add swipe gestures for navigation
- [ ] Add animated list items
- [ ] Add skeleton loaders
- [ ] Add better form validation visual feedback
