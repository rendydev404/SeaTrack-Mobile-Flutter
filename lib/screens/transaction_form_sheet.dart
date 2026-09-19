import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/transaction.dart';
import '../providers/transaction_provider.dart';

/// Membuka lembar tambah/ubah transaksi. Mengembalikan `true` bila tersimpan.
Future<bool?> showTransactionForm(BuildContext context, {TransactionModel? existing}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _TransactionForm(existing: existing),
  );
}

class _TransactionForm extends StatefulWidget {
  const _TransactionForm({this.existing});
  final TransactionModel? existing;

  @override
  State<_TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<_TransactionForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _amount;
  late TxType _type;
  late DateTime _when;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? TxType.expense;
    _when = e?.createdAt.toLocal() ?? DateTime.now();
    _title = TextEditingController(text: e?.title ?? '');
    _amount = TextEditingController(
      text: e == null ? '' : _ThousandsFormatter.format(e.amount.round()),
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when),
    );
    if (!mounted) return;
    setState(() {
      _when = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _when.hour,
        time?.minute ?? _when.minute,
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final amount = _ThousandsFormatter.parse(_amount.text);
    final tx = TransactionModel(
      id: widget.existing?.id,
      title: _title.text.trim(),
      amount: amount,
      type: _type,
      createdAt: _when,
    );
    final provider = context.read<TransactionProvider>();
    try {
      if (_isEdit) {
        await provider.edit(tx);
      } else {
        await provider.add(tx);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan. Periksa koneksi lalu coba lagi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEdit ? 'Ubah Transaksi' : 'Catat Transaksi',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            SegmentedButton<TxType>(
              segments: const [
                ButtonSegment(
                  value: TxType.expense,
                  label: Text('Keluar'),
                  icon: Icon(Icons.arrow_upward_rounded, size: 18),
                ),
                ButtonSegment(
                  value: TxType.income,
                  label: Text('Masuk'),
                  icon: Icon(Icons.arrow_downward_rounded, size: 18),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor:
                    (_type == TxType.income ? AppColors.income : AppColors.expense).withValues(alpha: 0.15),
                selectedForegroundColor: _type == TxType.income ? AppColors.income : AppColors.expense,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amount,
              autofocus: !_isEdit,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, _ThousandsFormatter()],
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                labelText: 'Nominal',
                prefixText: 'Rp ',
              ),
              validator: (v) {
                final n = _ThousandsFormatter.parse(v ?? '');
                if (n <= 0) return 'Nominal harus lebih dari 0';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Keterangan',
                hintText: 'Contoh: Makan siang',
                counterText: '',
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Keterangan wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDateTime,
              borderRadius: BorderRadius.circular(14),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Waktu',
                  suffixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                ),
                child: Text(Fmt.full(_when), style: const TextStyle(fontSize: 15)),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: scheme.onPrimary),
                    )
                  : Text(_isEdit ? 'Simpan Perubahan' : 'Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Menampilkan pemisah ribuan saat mengetik nominal (contoh: 1.250.000).
class _ThousandsFormatter extends TextInputFormatter {
  static final _fmt = NumberFormat.decimalPattern('id_ID');

  static String format(int v) => _fmt.format(v);

  static double parse(String s) => double.tryParse(s.replaceAll('.', '')) ?? 0;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll('.', '');
    if (digits.isEmpty) return newValue.copyWith(text: '');
    final n = int.tryParse(digits);
    if (n == null) return oldValue;
    final text = _fmt.format(n);
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
