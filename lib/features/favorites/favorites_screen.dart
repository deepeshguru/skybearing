import 'package:astro_engine/astro_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/offline_sky_app.dart';
import '../../app/providers.dart';
import '../../core/models/celestial_target.dart';
import '../object_details/object_details_screen.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(skyStateProvider);
    final repository = ref.watch(catalogRepositoryProvider);
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Eyebrow('Your sky collection'),
                  const SizedBox(height: 5),
                  Text(
                    'Saved objects',
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Favorites are stored on this device.',
                    style: TextStyle(color: Color(0xFF9AA8BD)),
                  ),
                ],
              ),
            ),
          ),
          if (state.isRestoring)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.favorites.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.bookmark_outline,
                title: 'No saved objects yet',
                body: 'Open an object and tap the bookmark to keep it here.',
              ),
            )
          else
            repository.when(
              loading: () => const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.storage_outlined,
                  title: 'Local catalog unavailable',
                  body: '$error',
                ),
              ),
              data: (repo) => SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                sliver: SliverList.builder(
                  itemCount: state.favorites.length,
                  itemBuilder: (context, index) {
                    final id = state.favorites.elementAt(index);
                    final solar = _solarTarget(id);
                    if (solar != null) {
                      return _FavoriteTile(target: solar);
                    }
                    return FutureBuilder(
                      future: repo.getById(id),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Padding(
                            padding: EdgeInsets.all(12),
                            child: LinearProgressIndicator(),
                          );
                        }
                        final object = snapshot.data;
                        if (object == null) return const SizedBox.shrink();
                        return _FavoriteTile(
                          target: CelestialTarget.catalog(object),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  CelestialTarget? _solarTarget(String id) {
    if (!id.startsWith('solar:')) return null;
    final name = id.substring('solar:'.length);
    for (final body in SolarBody.values) {
      if (body.name == name) return CelestialTarget.solar(body);
    }
    return null;
  }
}

class _FavoriteTile extends StatelessWidget {
  const _FavoriteTile({required this.target});
  final CelestialTarget target;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Card(
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFF1B2D45),
          child: Icon(Icons.bookmark, color: skyAccent, size: 19),
        ),
        title: Text(
          target.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${target.kind} · ${target.id}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ObjectDetailsScreen(target: target),
          ),
        ),
      ),
    ),
  );
}
