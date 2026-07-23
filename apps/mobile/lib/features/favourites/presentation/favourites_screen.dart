import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/widgets/empty_state.dart';
import '../data/favourites_repository.dart';

/// A single place to review the two rider conveniences: favourite drivers and
/// saved routes. Both are managed elsewhere (heart on a driver, bookmark on the
/// search form) — this screen is for reviewing and removing them.
class FavouritesScreen extends StatefulWidget {
  const FavouritesScreen({super.key});

  @override
  State<FavouritesScreen> createState() => _FavouritesScreenState();
}

class _FavouritesScreenState extends State<FavouritesScreen> {
  late Future<
      ({List<FavouriteDriver> drivers, List<SavedRoute> routes})> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<({List<FavouriteDriver> drivers, List<SavedRoute> routes})> _load() async {
    final repo = context.read<FavouritesRepository>();
    final drivers = await repo.listFavourites();
    final routes = await repo.listRoutes();
    return (drivers: drivers, routes: routes);
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _removeDriver(String id) async {
    await context.read<FavouritesRepository>().removeFavourite(id);
    _reload();
  }

  Future<void> _deleteRoute(String id) async {
    await context.read<FavouritesRepository>().deleteRoute(id);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Favourites'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Drivers'),
              Tab(text: 'Saved routes'),
            ],
          ),
        ),
        body: FutureBuilder<({List<FavouriteDriver> drivers, List<SavedRoute> routes})>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return EmptyState(
                icon: Icons.wifi_off_rounded,
                title: 'Could not load favourites',
                message: 'Check your connection and try again.',
                isError: true,
                action: TextButton(onPressed: _reload, child: const Text('Retry')),
              );
            }
            final data = snap.data!;
            return TabBarView(
              children: [
                // Drivers
                data.drivers.isEmpty
                    ? const EmptyState(
                        icon: Icons.favorite_border_rounded,
                        title: 'No favourite drivers yet',
                        message: 'Tap the heart on a driver to add them here.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: data.drivers.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final d = data.drivers[i];
                          final name = (d.name?.trim().isNotEmpty ?? false)
                              ? d.name!.trim()
                              : 'Driver';
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  theme.colorScheme.primary.withValues(alpha: 0.12),
                              child: Text(name[0].toUpperCase(),
                                  style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w800)),
                            ),
                            title: Text(name),
                            subtitle: (d.ratingCount ?? 0) > 0
                                ? Text(
                                    '★ ${d.ratingAvg?.toStringAsFixed(1)} (${d.ratingCount})')
                                : null,
                            trailing: IconButton(
                              tooltip: 'Remove',
                              icon: const Icon(Icons.favorite_rounded),
                              color: theme.colorScheme.primary,
                              onPressed: () => _removeDriver(d.driverId),
                            ),
                          );
                        },
                      ),
                // Saved routes
                data.routes.isEmpty
                    ? const EmptyState(
                        icon: Icons.bookmark_border_rounded,
                        title: 'No saved routes yet',
                        message:
                            'Use the bookmark on the search form to save a route.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: data.routes.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final r = data.routes[i];
                          return ListTile(
                            leading: Icon(Icons.bookmark_rounded,
                                color: theme.colorScheme.primary),
                            title: Text(r.label?.isNotEmpty == true
                                ? r.label!
                                : '${r.originLabel} → ${r.destLabel}'),
                            subtitle: r.label?.isNotEmpty == true
                                ? Text('${r.originLabel} → ${r.destLabel}')
                                : null,
                            trailing: IconButton(
                              tooltip: 'Delete',
                              icon: const Icon(Icons.delete_outline_rounded),
                              onPressed: () => _deleteRoute(r.id),
                            ),
                          );
                        },
                      ),
              ],
            );
          },
        ),
      ),
    );
  }
}
