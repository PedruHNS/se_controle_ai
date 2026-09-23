import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:reactive_forms/reactive_forms.dart';

class TextFieldCustomWidget<T> extends StatelessWidget {
  final String formControlName;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final Map<String, ValidationMessageFunction>? validationMessages;
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final String? prefixText;
  final bool autofocus;
  final TextInputAction textInputAction;
  final ControlValueAccessor<T, String>? valueAccessor;

  const TextFieldCustomWidget({
    super.key,
    required this.formControlName,
    this.keyboardType,
    this.inputFormatters,
    this.validationMessages,
    this.labelText,
    this.hintText,
    this.helperText,
    this.prefixText,
    this.autofocus = false,
    this.textInputAction = TextInputAction.next,
    this.valueAccessor,
  });

  @override
  Widget build(BuildContext context) {
    return ReactiveTextField<T>(
      formControlName: formControlName,
      keyboardType: keyboardType,
      valueAccessor: valueAccessor,
      autofocus: autofocus,
      onTapOutside: (event) => FocusScope.of(context).unfocus(),
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      validationMessages: validationMessages,
      
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        helperText: helperText,
        prefixText: prefixText,
        border: OutlineInputBorder(),
      ),
    );
  }
}
