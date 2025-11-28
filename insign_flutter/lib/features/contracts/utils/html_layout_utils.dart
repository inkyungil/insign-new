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

  // Check for special classes
  final className = element.className;

  // Handle special class-based styles
  if (className.contains('article') || className.contains('clause')) {
    return const {
      'margin': '12px 0',
      'padding': '10px 14px',
      'border-left': '3px solid #e0e0e0',
      'background': '#fafafa',
    };
  }

  if (className.contains('article-number')) {
    return const {
      'font-weight': '700',
      'font-size': '15px',
      'color': '#2c3e50',
      'margin-bottom': '6px',
    };
  }

  if (className.contains('important-box')) {
    return const {
      'margin': '14px 0',
      'padding': '14px',
      'background': '#fff3cd',
      'border': '2px solid #ffc107',
      'border-radius': '4px',
    };
  }

  if (className.contains('notice-box')) {
    return const {
      'margin': '14px 0',
      'padding': '14px',
      'background': '#f8f9fa',
      'border': '2px solid #dee2e6',
      'border-radius': '4px',
    };
  }

  if (className.contains('signature-section')) {
    return const {
      'margin-top': '32px',
      'padding-top': '20px',
      'border-top': '2px solid #e0e0e0',
    };
  }

  if (className.contains('signature-box')) {
    return const {
      'margin': '20px 0',
      'padding': '14px',
      'border': '2px solid #2c3e50',
      'background': '#ffffff',
    };
  }

  if (className.contains('signature-title')) {
    return const {
      'font-weight': '700',
      'font-size': '15px',
      'margin-bottom': '10px',
      'color': '#2c3e50',
    };
  }

  if (className.contains('signature-image-box')) {
    return const {
      'margin': '14px 0',
      'padding': '14px',
      'border': '1.5px dashed #95a5a6',
      'background': '#fafafa',
      'min-height': '60px',
      'text-align': 'center',
    };
  }

  if (className.contains('contract-date')) {
    return const {
      'text-align': 'center',
      'margin': '20px 0',
      'font-size': '14px',
      'font-weight': '600',
    };
  }

  if (className.contains('parties-table')) {
    return const {
      'width': '100%',
      'max-width': '100%',
      'border': '1.5px solid #2c3e50',
      'border-collapse': 'collapse',
    };
  }

  // Handle tag-based styles
  switch (tag) {
    case 'h1':
      return const {
        'font-size': '22px',
        'font-weight': '700',
        'text-align': 'center',
        'margin-bottom': '8px',
        'padding-top': '12px',
        'padding-bottom': '12px',
        'border-bottom': '3px solid #2c3e50',
        'color': '#000000',
      };
    case 'h2':
      return const {
        'font-size': '18px',
        'font-weight': '700',
        'margin-top': '20px',
        'margin-bottom': '10px',
        'padding-left': '4px',
        'border-left': '4px solid #3498db',
        'color': '#000000',
      };
    case 'h3':
      return const {
        'font-size': '16px',
        'font-weight': '700',
        'margin-top': '14px',
        'margin-bottom': '8px',
        'color': '#000000',
      };
    case 'p':
      return const {
        'margin': '6px 0',
        'line-height': '1.7',
        'text-align': 'justify',
      };
    case 'table':
      return const {
        'width': '100%',
        'max-width': '100%',
        'min-width': '100%',
        'table-layout': 'fixed',
        'display': 'table',
        'box-sizing': 'border-box',
        'border-collapse': 'collapse',
        'margin': '14px 0',
        'border': '1.5px solid #2c3e50',
      };
    case 'th':
      return const {
        'padding': '10px 12px',
        'border': '1px solid #95a5a6',
        'background': '#ecf0f1',
        'font-weight': '700',
        'color': '#2c3e50',
        'text-align': 'center',
        'vertical-align': 'top',
        'word-break': 'break-word',
        'display': 'table-cell',
        'box-sizing': 'border-box',
      };
    case 'td':
      return const {
        'padding': '10px 12px',
        'border': '1px solid #95a5a6',
        'width': 'auto',
        'vertical-align': 'top',
        'word-break': 'break-word',
        'display': 'table-cell',
        'box-sizing': 'border-box',
      };
    case 'tr':
      // Alternating row colors handled by pseudo-selectors in CSS
      return const {
        'background': '#ffffff',
      };
    case 'img':
      return const {
        'max-width': '100%',
        'height': 'auto',
        'display': 'block',
      };
    case 'ul':
    case 'ol':
      return const {
        'margin': '6px 0',
        'padding-left': '20px',
      };
    case 'li':
      return const {
        'margin': '4px 0',
      };
    case 'strong':
    case 'b':
      return const {
        'font-weight': '700',
        'color': '#2c3e50',
      };
    case 'em':
    case 'i':
      return const {
        'font-style': 'italic',
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
