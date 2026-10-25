import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    final builder = CBuilder.library(
      name: input.packageName,
      assetName: '${input.packageName}_bindings_generated.dart',
      sources: ['src/astro_bridge.c', 'src/upstream/astronomy.c'],
      includes: ['src', 'src/upstream'],
      libraries: ['m'],
      std: 'c99',
      flags: ['-Wall', '-Wextra', '-Wno-unused-parameter'],
    );
    await builder.run(input: input, output: output);
  });
}
