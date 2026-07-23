import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../safety/data/blocks_repository.dart';
import '../data/disputes_repository.dart';

const _categories = [
  'Driver behaviour',
  'Safety concern',
  'Payment / fare',
  'No-show',
  'Vehicle condition',
  'Other',
];

/// Opens the "Report a problem" sheet.
///
/// Pass [reportedUserId] when the complaint is about a PERSON — the sheet then
/// also offers to block them, which is what a user actually wants in the
/// moment they feel unsafe.
Future<void> showReportSheet(
  BuildContext context, {
  String? bookingId,
  String? reportedUserId,
  String? reportedName,
}) async {
  final repo = context.read<DisputesRepository>();
  final blocks = context.read<BlocksRepository>();
  final messenger = ScaffoldMessenger.of(context);
  final blocked = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _ReportForm(
        repo: repo,
        blocks: blocks,
        bookingId: bookingId,
        reportedUserId: reportedUserId,
        reportedName: reportedName,
      ),
    ),
  );
  if (blocked == null) return; // dismissed without filing
  messenger.showSnackBar(SnackBar(
    content: Text(blocked
        ? 'Report submitted and ${reportedName ?? 'this person'} blocked.'
        : 'Report submitted — our team will look into it.'),
  ));
}

class _ReportForm extends StatefulWidget {
  const _ReportForm({
    required this.repo,
    required this.blocks,
    this.bookingId,
    this.reportedUserId,
    this.reportedName,
  });

  final DisputesRepository repo;
  final BlocksRepository blocks;
  final String? bookingId;
  final String? reportedUserId;
  final String? reportedName;

  @override
  State<_ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends State<_ReportForm> {
  String _category = _categories.first;
  final _message = TextEditingController();
  bool _busy = false;
  bool _alsoBlock = false;
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_message.text.trim().isEmpty) {
      setState(() => _error = 'Please describe the problem');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repo.file(
        category: _category,
        message: _message.text.trim(),
        bookingId: widget.bookingId,
        reportedUserId: widget.reportedUserId,
      );
      // The block is secondary: if it fails, the report still stands, so it
      // must not turn a filed report into an error the user sees.
      var blocked = false;
      if (_alsoBlock && widget.reportedUserId != null) {
        try {
          await widget.blocks.block(widget.reportedUserId!, reason: _category);
          blocked = true;
        } catch (_) {
          /* reported successfully; blocking can be retried from Profile */
        }
      }
      if (mounted) Navigator.of(context).pop(blocked);
    } catch (_) {
      setState(() {
        _busy = false;
        _error = 'Could not submit — please try again';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Report a problem',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
            items: [for (final c in _categories) DropdownMenuItem(value: c, child: Text(c))],
            onChanged: (v) => setState(() => _category = v ?? _category),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _message,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'What happened?',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          if (widget.reportedUserId != null) ...[
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _alsoBlock,
              onChanged: _busy ? null : (v) => setState(() => _alsoBlock = v),
              title: Text('Also block ${widget.reportedName ?? 'this person'}'),
              subtitle: const Text(
                "You won't be shown to each other again, and neither of you can book the other.",
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Submit report'),
            ),
          ),
        ],
      ),
    );
  }
}
