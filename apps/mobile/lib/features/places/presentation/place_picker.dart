import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../rides/data/rides_repository.dart' show Hub;
import '../data/places_repository.dart';

/// Opens the address picker; returns the chosen [Hub] (label + coords) or null.
Future<Hub?> showPlacePicker(
  BuildContext context, {
  required String title,
  required List<Hub> hubs,
  String? city,
}) {
  return showModalBottomSheet<Hub>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _PlacePickerSheet(title: title, hubs: hubs, city: city),
    ),
  );
}

class _PlacePickerSheet extends StatefulWidget {
  const _PlacePickerSheet({required this.title, required this.hubs, this.city});
  final String title;
  final List<Hub> hubs;
  final String? city;

  @override
  State<_PlacePickerSheet> createState() => _PlacePickerSheetState();
}

class _PlacePickerSheetState extends State<_PlacePickerSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<Hub> _results = [];
  bool _loading = false;
  int _reqId = 0;

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 3) {
      setState(() {
        _results = [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(value));
  }

  Future<void> _search(String value) async {
    final id = ++_reqId;
    try {
      final hits =
          await context.read<PlacesRepository>().search(value, city: widget.city);
      if (!mounted || id != _reqId) return; // ignore stale responses
      setState(() {
        _results = hits;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || id != _reqId) return;
      setState(() {
        _results = [];
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showHubs = _controller.text.trim().length < 3;
    final list = showHubs ? widget.hubs : _results;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.72,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(widget.title,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: 'Search any address or area',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                            width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                    : null,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ),
          if (showHubs)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Text('POPULAR POINTS',
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5)),
            ),
          Expanded(
            child: !showHubs && !_loading && list.isEmpty
                ? Center(
                    child: Text('No matches — try a landmark or area name',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.outline)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 4),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final hub = list[i];
                      return ListTile(
                        leading: Icon(
                            showHubs ? Icons.push_pin_outlined : Icons.location_on_outlined,
                            color: theme.colorScheme.primary),
                        title: Text(hub.label, maxLines: 2, overflow: TextOverflow.ellipsis),
                        onTap: () => Navigator.of(context).pop(hub),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
