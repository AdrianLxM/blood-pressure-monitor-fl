import 'package:blood_pressure_app/features/input/forms/form_base.dart';
import 'package:blood_pressure_app/l10n/app_localizations.dart';
import 'package:blood_pressure_app/model/blood_pressure/pressure_unit.dart';
import 'package:blood_pressure_app/model/storage/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:health_data_store/health_data_store.dart';
import 'package:provider/provider.dart';

/// Form to enter freeform text and select color.
class BloodPressureForm extends FormBase<({Pressure? sys, Pressure? dia, int? pul})> {
  /// Create form to enter freeform text and select color.
  const BloodPressureForm({super.key,
    super.initialValue,
  });

  @override
  BloodPressureFormState createState() => BloodPressureFormState();
}

/// State of form to enter freeform text and select color.
class BloodPressureFormState extends FormStateBase<({Pressure? sys, Pressure? dia, int? pul}), BloodPressureForm> {
  final _formKey = GlobalKey<FormState>();

  final _sysFocusNode = FocusNode();
  final _diaFocusNode = FocusNode();
  final _pulFocusNode = FocusNode();

  late final TextEditingController _sysController;
  late final TextEditingController _diaController;
  late final TextEditingController _pulController;

  PressureUnit get _unit => context.read<Settings>().preferredPressureUnit;
  String _format(Pressure? p) => p == null ? '' : _unit.prettyPrint(p);
  num? _parse(String? text) => num.tryParse((text ?? '').replaceAll(',', '.'));
  Pressure? _parsePressure(String? text) {
    final value = _parse(text);
    return value == null ? null : _unit.wrap(value);
  }

  // Loaded values are returned as is when unchanged to avoid rounding errors.
  Pressure? _initialSys;
  Pressure? _initialDia;
  Pressure? _parseOrKeep(String text, Pressure? initial) =>
      (initial != null && text == _format(initial)) ? initial : _parsePressure(text);

  @override
  void initState() {
    super.initState();
    _initialSys = widget.initialValue?.sys;
    _initialDia = widget.initialValue?.dia;
    _sysController = TextEditingController(text: _format(widget.initialValue?.sys));
    _diaController = TextEditingController(text: _format(widget.initialValue?.dia));
    _pulController = TextEditingController(text: widget.initialValue?.pul?.toString() ?? '');
    _sysFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _sysFocusNode.dispose();
    _diaFocusNode.dispose();
    _pulFocusNode.dispose();
    _sysController.dispose();
    _diaController.dispose();
    _pulController.dispose();
    super.dispose();
  }

  @override
  bool validate() {
    if (_sysController.text.isEmpty
        && _diaController.text.isEmpty
        && _pulController.text.isEmpty) {
      return true;
    }
    return _formKey.currentState?.validate() ?? false;
  }

  @override
  ({Pressure? sys, Pressure? dia, int? pul})? save() {
    if (!validate()
      || (_parse(_sysController.text) == null
      && _parse(_diaController.text) == null
      && int.tryParse(_pulController.text) == null)) {
      return null;
    }
    return (
      sys: _parseOrKeep(_sysController.text, _initialSys),
      dia: _parseOrKeep(_diaController.text, _initialDia),
      pul: int.tryParse(_pulController.text),
    );
  }

  @override
  bool isEmptyInputFocused() => (_diaFocusNode.hasFocus && _diaController.text.isEmpty)
   || (_pulFocusNode.hasFocus && _pulController.text.isEmpty);

  @override
  void fillForm(({Pressure? dia, int? pul, Pressure? sys})? value) => setState(() {
    _initialSys = value?.sys;
    _initialDia = value?.dia;
    if (value == null) {
        _sysController.text = '';
        _diaController.text = '';
        _pulController.text = '';
    } else {
      if (value.dia != null) _diaController.text = _format(value.dia);
      if (value.pul != null) _pulController.text = value.pul.toString();
      if (value.sys != null) _sysController.text = _format(value.sys);
    }
  });

  @override
  bool get isEmpty => (
      _sysController.text.isEmpty
      && _diaController.text.isEmpty
      && _pulController.text.isEmpty
  );

  Widget _buildValueInput({
    String? labelText,
    FocusNode? focusNode,
    TextEditingController? controller,
    String? Function(String?)? validator,
    bool isPressure = true,
  }) => Expanded(
    child: TextFormField(
      focusNode: focusNode,
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(
        decimal: isPressure && _unit == PressureUnit.kPa,
      ),
      inputFormatters: [
        if (isPressure && _unit == PressureUnit.kPa) FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
        else FilteringTextInputFormatter.digitsOnly,
      ],
      onChanged: (String value) {
        if (value.isNotEmpty
            && (int.tryParse(value) ?? -1) > 40) {
          FocusScope.of(context).nextFocus();
        }
      },
      validator: (String? value) {
        final settings = context.read<Settings>();
        final num? comparable = isPressure
          ? _parsePressure(value)?.mmHg
          : int.tryParse(value ?? '');
        if (!settings.allowMissingValues
            && (value == null
                || value.isEmpty
                || _parse(value) == null)) {
          return AppLocalizations.of(context)!.errNaN;
        } else if (settings.validateInputs
            && (comparable ?? -1) <= 30) {
          return AppLocalizations.of(context)!.errLt30;
        } else if (settings.validateInputs
            && (comparable ?? 0) >= 400) {
          // https://pubmed.ncbi.nlm.nih.gov/7741618/
          return AppLocalizations.of(context)!.errUnrealistic;
        }
        return validator?.call(value);
      },
      decoration: InputDecoration(
        labelText: labelText,
      ),
      style: Theme.of(context).textTheme.bodyLarge,
    ),
  );

  @override
  Widget build(BuildContext context) => Form(
    key: _formKey,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildValueInput(
          focusNode: _sysFocusNode,
          controller: _sysController,
          labelText: AppLocalizations.of(context)!.sysLong,
        ),
        const SizedBox(width: 8,),
        _buildValueInput(
          labelText: AppLocalizations.of(context)!.diaLong,
          controller: _diaController,
          focusNode: _diaFocusNode,
          validator: (value) {
            if (context.read<Settings>().validateInputs
              && (_parse(value) ?? 0)
                >= (_parse(_sysController.text) ?? 1)) {
              return AppLocalizations.of(context)?.errDiaGtSys;
            }
            return null;
          },
        ),
        const SizedBox(width: 8,),
        _buildValueInput(
          controller: _pulController,
          focusNode: _pulFocusNode,
          labelText: AppLocalizations.of(context)!.pulLong,
          isPressure: false,
        ),
      ],
    ),
  );
}
