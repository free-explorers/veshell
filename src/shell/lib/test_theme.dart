import 'package:flutter/material.dart';

class TextThemeComparison extends StatelessWidget {
  const TextThemeComparison({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TextTheme Font Comparison'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            _buildComparisonTable(context),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonTable(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final robotoTheme = textTheme;
    // Create a TextTheme that follows Material Design 3 specs using RobotoFlex
    const robotoFlexTheme = TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'RobotoFlex',
        fontSize: 57,
        fontWeight: FontWeight.w400,
        height: 64 / 57, // Line height as a multiplier
        letterSpacing: -0.25,
        fontVariations: [
          FontVariation('wght', 400),
          FontVariation('wdth', 100),
        ],
      ),
      displayMedium: TextStyle(
        fontFamily: 'RobotoFlex',
        fontSize: 45,
        fontWeight: FontWeight.w400,
        height: 52 / 45,
        letterSpacing: 0,
        fontVariations: [
          FontVariation('wght', 400),
          FontVariation('wdth', 100),
        ],
      ),
      displaySmall: TextStyle(
        fontFamily: 'RobotoFlex',
        fontSize: 36,
        fontWeight: FontWeight.w400,
        height: 44 / 36,
        letterSpacing: 0,
        fontVariations: [
          FontVariation('wght', 400),
          FontVariation('wdth', 100),
        ],
      ),
      headlineLarge: TextStyle(
        fontFamily: 'RobotoFlex',
        fontSize: 32,
        fontWeight: FontWeight.w400,
        height: 40 / 32,
        letterSpacing: 0,
        fontVariations: [
          FontVariation('wght', 400),
          FontVariation('wdth', 100),
        ],
      ),
      headlineMedium: TextStyle(
        fontFamily: 'RobotoFlex',
        fontSize: 28,
        fontWeight: FontWeight.w400,
        height: 36 / 28,
        letterSpacing: 0,
        fontVariations: [
          FontVariation('wght', 400),
          FontVariation('wdth', 100),
        ],
      ),
      headlineSmall: TextStyle(
        fontFamily: 'RobotoFlex',
        fontSize: 24,
        fontWeight: FontWeight.w400,
        height: 32 / 24,
        letterSpacing: 0,
        fontVariations: [
          FontVariation('wght', 400),
          FontVariation('wdth', 100),
        ],
      ),
      titleLarge: TextStyle(
        fontFamily: 'RobotoFlex',
        fontSize: 22,
        fontWeight: FontWeight.w400,
        height: 28 / 22,
        letterSpacing: 0,
        fontVariations: [
          FontVariation('wght', 400),
          FontVariation('wdth', 100),
        ],
      ),
      titleMedium: TextStyle(
        fontFamily: 'RobotoFlex',
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 24 / 16,
        letterSpacing: 0.15,
        fontVariations: [
          FontVariation('wght', 500),
          FontVariation('wdth', 100),
        ],
      ),
      titleSmall: TextStyle(
        fontFamily: 'RobotoFlex',
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 20 / 14,
        letterSpacing: 0.1,
        fontVariations: [
          FontVariation('wght', 500),
          FontVariation('wdth', 100),
        ],
      ),
      bodyLarge: TextStyle(
        fontFamily: 'RobotoFlex',
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
        letterSpacing: 0.5,
        fontVariations: [
          FontVariation('wght', 400),
          FontVariation('wdth', 100),
        ],
      ),
      bodyMedium: TextStyle(
        fontFamily: 'RobotoFlex',
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        letterSpacing: 0.25,
        fontVariations: [
          FontVariation('wght', 400),
          FontVariation('wdth', 100),
        ],
      ),
      bodySmall: TextStyle(
        fontFamily: 'RobotoFlex',
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 16 / 12,
        letterSpacing: 0.4,
        fontVariations: [
          FontVariation('wght', 400),
          FontVariation('wdth', 100),
        ],
      ),
      labelLarge: TextStyle(
        fontFamily: 'RobotoFlex',
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 20 / 14,
        letterSpacing: 0.1,
        fontVariations: [
          FontVariation('wght', 500),
          FontVariation('wdth', 100),
        ],
      ),
      labelMedium: TextStyle(
        fontFamily: 'RobotoFlex',
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 16 / 12,
        letterSpacing: 0.5,
        fontVariations: [
          FontVariation('wght', 500),
          FontVariation('wdth', 100),
        ],
      ),
      labelSmall: TextStyle(
        fontFamily: 'RobotoFlex',
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 16 / 11,
        letterSpacing: 0.5,
        fontVariations: [
          FontVariation('wght', 500),
          FontVariation('wdth', 100),
        ],
      ),
    );

    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      columnWidths: const {
        0: FlexColumnWidth(),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(2),
        3: FlexColumnWidth(2),
      },
      children: [
        _buildTableHeader(),
        _buildStyleRow(
          'displayLarge',
          robotoTheme.displayLarge,
          robotoFlexTheme.displayLarge,
        ),
        _buildStyleRow(
          'displayMedium',
          robotoTheme.displayMedium,
          robotoFlexTheme.displayMedium,
        ),
        _buildStyleRow(
          'displaySmall',
          robotoTheme.displaySmall,
          robotoFlexTheme.displaySmall,
        ),
        _buildStyleRow(
          'headlineLarge',
          robotoTheme.headlineLarge,
          robotoFlexTheme.headlineLarge,
        ),
        _buildStyleRow(
          'headlineMedium',
          robotoTheme.headlineMedium,
          robotoFlexTheme.headlineMedium,
        ),
        _buildStyleRow(
          'headlineSmall',
          robotoTheme.headlineSmall,
          robotoFlexTheme.headlineSmall,
        ),
        _buildStyleRow(
          'titleLarge',
          robotoTheme.titleLarge,
          robotoFlexTheme.titleLarge,
        ),
        _buildStyleRow(
          'titleMedium',
          robotoTheme.titleMedium,
          robotoFlexTheme.titleMedium,
        ),
        _buildStyleRow(
          'titleSmall',
          robotoTheme.titleSmall,
          robotoFlexTheme.titleSmall,
        ),
        _buildStyleRow(
          'bodyLarge',
          robotoTheme.bodyLarge,
          robotoFlexTheme.bodyLarge,
        ),
        _buildStyleRow(
          'bodyMedium',
          robotoTheme.bodyMedium,
          robotoFlexTheme.bodyMedium,
        ),
        _buildStyleRow(
          'bodySmall',
          robotoTheme.bodySmall,
          robotoFlexTheme.bodySmall,
        ),
        _buildStyleRow(
          'labelLarge',
          robotoTheme.labelLarge,
          robotoFlexTheme.labelLarge,
        ),
        _buildStyleRow(
          'labelMedium',
          robotoTheme.labelMedium,
          robotoFlexTheme.labelMedium,
        ),
        _buildStyleRow(
          'labelSmall',
          robotoTheme.labelSmall,
          robotoFlexTheme.labelSmall,
        ),
      ],
    );
  }

  TableRow _buildTableHeader() {
    return TableRow(
      decoration: BoxDecoration(color: Colors.grey.shade200),
      children: [
        _buildHeaderCell('Style Name'),
        _buildHeaderCell('Roboto'),
        _buildHeaderCell('RobotoFlex'),
        _buildHeaderCell('Overlapped'),
      ],
    );
  }

  Widget _buildHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }

  TableRow _buildStyleRow(
    String styleName,
    TextStyle? robotoStyle,
    TextStyle? robotoFlexStyle,
  ) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(styleName),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Example Text', style: robotoStyle),
              const SizedBox(height: 4),
              Text(
                'Font: ${robotoStyle?.fontFamily ?? 'default'}\n'
                'Size: ${robotoStyle?.fontSize?.toStringAsFixed(1) ?? 'N/A'}\n'
                'Weight: ${robotoStyle?.fontWeight ?? 'N/A'}\n'
                'Letter Spacing: ${robotoStyle?.letterSpacing?.toStringAsFixed(2) ?? '0.0'}\n'
                'Line Height: ${robotoStyle?.height?.toStringAsFixed(2) ?? 'default'}\n'
                'Color: ${robotoStyle?.color ?? 'default'}',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Example Text', style: robotoFlexStyle),
              const SizedBox(height: 4),
              Text(
                'Font: ${robotoFlexStyle?.fontFamily ?? 'default'}\n'
                'Size: ${robotoFlexStyle?.fontSize?.toStringAsFixed(1) ?? 'N/A'}\n'
                'Weight: ${robotoFlexStyle?.fontWeight ?? 'N/A'}\n'
                'Letter Spacing: ${robotoFlexStyle?.letterSpacing?.toStringAsFixed(2) ?? '0.0'}\n'
                'Line Height: ${robotoFlexStyle?.height?.toStringAsFixed(2) ?? 'default'}\n'
                'Variations: ${_formatVariations(robotoFlexStyle?.fontVariations)}',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Text(
                    'Example Text',
                    style: robotoStyle?.copyWith(
                      color: Colors.blue.withOpacity(0.5),
                    ),
                  ),
                  Text(
                    'Example Text',
                    style: robotoFlexStyle?.copyWith(
                      color: Colors.red.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Blue: Roboto\n'
                'Red: RobotoFlex\n'
                'Purple areas indicate overlap',
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helper method to format font variations for display
  String _formatVariations(List<FontVariation>? variations) {
    if (variations == null || variations.isEmpty) {
      return 'none';
    }
    return variations
        .map((v) => '${v.axis}:${v.value.toStringAsFixed(1)}')
        .join(', ');
  }
}
