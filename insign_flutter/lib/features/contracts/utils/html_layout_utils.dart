import 'package:html/dom.dart' as dom;
import 'package:universal_html/html.dart' as html;

/// Normalizes HTML snippets so contract tables expand to container width
/// while images scale responsively.
String normalizeContractHtmlLayout(String htmlContent) {
  if (htmlContent.trim().isEmpty) {
    return htmlContent;
  }

  final wrapper = html.DivElement();
  wrapper.setInnerHtml(
    htmlContent,
    treeSanitizer: html.NodeTreeSanitizer.trusted,
  );

  for (final table in wrapper.querySelectorAll('table')) {
    _removeDimensionAttributes(table);
    _applyInlineStyles(table, const {
      'width': '100%',
      'max-width': '100%',
      'min-width': '100%',
      'table-layout': 'fixed',
      'border-collapse': 'collapse',
      'display': 'table',
      'box-sizing': 'border-box',
    });
  }

  for (final cell in wrapper.querySelectorAll('td, th')) {
    _removeDimensionAttributes(cell);
    _applyInlineStyles(cell, const {
      'width': 'auto',
      'vertical-align': 'top',
      'word-break': 'break-word',
      'display': 'table-cell',
      'box-sizing': 'border-box',
    });
  }

  for (final image in wrapper.querySelectorAll('img')) {
    _removeDimensionAttributes(image);
    _applyInlineStyles(image, const {
      'max-width': '100%',
      'height': 'auto',
      'display': 'block',
    });
  }

  return wrapper.innerHtml ?? '';
}

/// Provides per-tag default styles used by HtmlWidget custom style builder.
Map<String, String>? buildContractHtmlStyles(dom.Element element) {
  final tag = element.localName;
  if (tag == null) {
    return null;
  }

  switch (tag) {
    case 'table':
      return const {
        'width': '100%',
        'max-width': '100%',
        'min-width': '100%',
        'table-layout': 'fixed',
        'display': 'table',
        'box-sizing': 'border-box',
      };
    case 'td':
    case 'th':
      return const {
        'width': 'auto',
        'vertical-align': 'top',
        'word-break': 'break-word',
        'display': 'table-cell',
        'box-sizing': 'border-box',
      };
    case 'img':
      return const {
        'max-width': '100%',
        'height': 'auto',
        'display': 'block',
      };
  }
  return null;
}

void _removeDimensionAttributes(html.Element element) {
  final keys = element.attributes.keys.toList();
  for (final key in keys) {
    final lower = key.toLowerCase();
    if (lower == 'width' || lower == 'height') {
      element.attributes.remove(key);
    }
  }
}

void _applyInlineStyles(html.Element element, Map<String, String> updates) {
  final styles = <String, String>{};

  final existing = element.getAttribute('style');
  if (existing != null && existing.trim().isNotEmpty) {
    for (final rule in existing.split(';')) {
      final trimmed = rule.trim();
      if (trimmed.isEmpty) continue;
      final separatorIndex = trimmed.indexOf(':');
      if (separatorIndex <= 0) continue;
      final key = trimmed.substring(0, separatorIndex).trim().toLowerCase();
      final value = trimmed.substring(separatorIndex + 1).trim();
      if (key.isEmpty || value.isEmpty) continue;
      styles[key] = value;
    }
  }

  updates.forEach((key, value) {
    styles[key] = value;
  });

  final styleString = styles.entries
      .map((entry) => '${entry.key}: ${entry.value}')
      .join('; ');
  element.setAttribute('style', styleString);
}
