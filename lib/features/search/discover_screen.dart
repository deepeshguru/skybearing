import 'dart:async';

import 'package:astro_engine/astro_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/offline_sky_app.dart';
import '../../app/providers.dart';
import '../../core/models/celestial_object.dart';
import '../../core/models/celestial_target.dart';
import '../object_details/object_details_screen.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(catalogRepositoryProvider);
    final q = _query.trim();
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Eyebrow('Explore the night sky'),
                  const SizedBox(height: 5),
                  Text(
                    'Discover',
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.search,
                    autocorrect: false,
                    onSubmitted: (_) => FocusScope.of(context).unfocus(),
                    onChanged: (value) {
                      _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 180), () {
                        if (mounted) setState(() => _query = value);
                      });
                    },
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, color: skyAccent),
                      hintText: 'Name, alias, NGC, Messier, HIP…',
                      suffixIcon: q.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () {
                                _controller.clear();
                                setState(() => _query = '');
                              },
                              icon: const Icon(Icons.close),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (q.isEmpty) ...[
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 11),
              sliver: SliverToBoxAdapter(child: SectionTitle('Solar System')),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.crossAxisExtent < 300 ? 1 : 2;
                  final textScale =
                      MediaQuery.textScalerOf(context).scale(14) / 14;
                  return SliverGrid.builder(
                    itemCount: SolarBody.values.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: (columns == 1 ? 4.3 : 2.35) / textScale,
                    ),
                    itemBuilder: (context, index) {
                      final body = SolarBody.values[index];
                      final target = CelestialTarget.solar(body);
                      return _TargetTile(
                        target: target,
                        onTap: () => _open(context, target),
                      );
                    },
                  );
                },
              ),
            ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 10),
              sliver: SliverToBoxAdapter(
                child: SectionTitle('Search the offline catalog'),
              ),
            ),
            const SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Search by common name, catalog number, alias, or HIP identifier. All results come from the bundled star and deep-sky catalog.',
                  style: TextStyle(color: Color(0xFF9AA8BD), height: 1.45),
                ),
              ),
            ),
          ] else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 7),
              sliver: SliverToBoxAdapter(
                child: Eyebrow('Offline results for “$q”'),
              ),
            ),
            ..._catalogResults(repository, q, context),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 26)),
        ],
      ),
    );
  }

  List<Widget> _catalogResults(
    AsyncValue<dynamic> repository,
    String query,
    BuildContext context,
  ) {
    final solar = CelestialTarget.solarSystem
        .where(
          (target) =>
              target.name.toLowerCase().contains(query.toLowerCase()) ||
              target.aliases.any(
                (alias) => alias.toLowerCase().contains(query.toLowerCase()),
              ),
        )
        .toList();
    return [
      if (solar.isNotEmpty)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          sliver: SliverList.builder(
            itemCount: solar.length,
            itemBuilder: (context, index) => _TargetTile(
              target: solar[index],
              onTap: () => _open(context, solar[index]),
            ),
          ),
        ),
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
        data: (repo) => SliverToBoxAdapter(
          child: FutureBuilder<List<CelestialObject>>(
            future: repo.search(query),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('Catalog search failed: ${snapshot.error}'),
                );
              }
              final objects = snapshot.data ?? const <CelestialObject>[];
              if (objects.isEmpty && solar.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.fromLTRB(24, 35, 24, 25),
                  child: EmptyState(
                    icon: Icons.search_off,
                    title: 'No matching objects',
                    body: 'Try a common name or a catalog identifier such as M31, NGC 224, or HIP 32349.',
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  children: objects
                      .map((object) {
                        final target = CelestialTarget.catalog(object);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: _TargetTile(
                            target: target,
                            onTap: () => _open(context, target),
                          ),
                        );
                      })
                      .toList(growable: false),
                ),
              );
            },
          ),
        ),
      ),
    ];
  }

  void _open(BuildContext context, CelestialTarget target) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ObjectDetailsScreen(target: target),
        ),
      );
}

class _TargetTile extends StatelessWidget {
  const _TargetTile({required this.target, required this.onTap});
  final CelestialTarget target;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: skyAccent.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_typeIcon(target.kind), color: skyAccent, size: 20),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    target.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${target.kind} · ${target.id}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: const Color(0xFF93A2B8)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF7788A1)),
          ],
        ),
      ),
    ),
  );
}

IconData _typeIcon(String kind) {
  final value = kind.toLowerCase();
  if (value.contains('star') || value.contains('sun')) {
    return Icons.auto_awesome;
  }
  if (value.contains('galaxy')) return Icons.blur_circular;
  if (value.contains('nebula')) return Icons.cloud_outlined;
  if (value.contains('cluster')) return Icons.grain;
  if (value.contains('planet')) return Icons.public;
  return Icons.stars;
}
