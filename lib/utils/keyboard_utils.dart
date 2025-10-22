import 'package:flutter/material.dart';

/// Utility class for keyboard management
class KeyboardUtils {
  /// Hide keyboard
  static void hideKeyboard(BuildContext context) {
    FocusScope.of(context).unfocus();
  }

  /// Show keyboard for a specific focus node
  static void showKeyboard(BuildContext context, FocusNode focusNode) {
    FocusScope.of(context).requestFocus(focusNode);
  }

  /// Check if keyboard is visible
  static bool isKeyboardVisible(BuildContext context) {
    return MediaQuery.of(context).viewInsets.bottom > 0;
  }

  /// Get keyboard height
  static double getKeyboardHeight(BuildContext context) {
    return MediaQuery.of(context).viewInsets.bottom;
  }
}

/// Widget that dismisses keyboard when tapping outside text fields
class DismissKeyboard extends StatelessWidget {
  final Widget child;

  const DismissKeyboard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => KeyboardUtils.hideKeyboard(context),
      child: child,
    );
  }
}

/// Form with automatic keyboard dismissal
class ResponsiveForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final List<Widget> children;
  final EdgeInsets? padding;
  final bool dismissKeyboardOnTap;

  const ResponsiveForm({
    super.key,
    required this.formKey,
    required this.children,
    this.padding,
    this.dismissKeyboardOnTap = true,
  });

  @override
  Widget build(BuildContext context) {
    final form = Form(
      key: formKey,
      child: ListView(
        padding: padding ?? const EdgeInsets.all(16),
        children: children,
      ),
    );

    if (dismissKeyboardOnTap) {
      return DismissKeyboard(child: form);
    }
    return form;
  }
}
