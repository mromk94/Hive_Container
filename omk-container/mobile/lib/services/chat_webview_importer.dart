import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'chat_import_models.dart';

/// WebView-based importer that loads a shared chat URL in a real browser
/// context and extracts a structured transcript via injected JavaScript.
///
/// This is used as a best-effort primary path for providers like ChatGPT
/// where the transcript may be hidden behind client-side hydration.
class ChatWebViewImporter {
  ChatWebViewImporter._();

  static Future<ImportedTranscript?> importViaWebView(
    BuildContext context,
    String url,
    ChatProviderType provider,
  ) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;

    var normalized = trimmed;
    if (!normalized.startsWith('http')) {
      if (normalized.startsWith('chat.openai.com') || normalized.startsWith('chatgpt.com')) {
        normalized = 'https://$normalized';
      }
    }

    final now = DateTime.now();
    try {
      assert(() {
        // Debug-only visibility into WebView imports during development.
        print('[ChatWebViewImporter] Starting WebView import for provider '
            '${provider.name} with URL: $normalized');
        return true;
      }());
      final messages = await Navigator.of(context).push<List<ImportedMessage>>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => _ChatImportWebViewScreen(
            initialUrl: normalized,
            provider: provider,
          ),
        ),
      );
      if (messages == null || messages.isEmpty) return null;
      assert(() {
        print('[ChatWebViewImporter] WebView import produced '
            '${messages.length} messages for provider ${provider.name}.');
        return true;
      }());
      return ImportedTranscript(
        sourceUrl: normalized,
        providerId: provider.name,
        fetchedAt: now,
        messages: messages,
      );
    } catch (e) {
      assert(() {
        print('[ChatWebViewImporter] WebView import failed for provider '
            '${provider.name}: $e');
        return true;
      }());
      return null;
    }
  }
}

class _ChatImportWebViewScreen extends StatefulWidget {
  const _ChatImportWebViewScreen({
    required this.initialUrl,
    required this.provider,
  });

  final String initialUrl;
  final ChatProviderType provider;

  @override
  State<_ChatImportWebViewScreen> createState() => _ChatImportWebViewScreenState();
}

class _ChatImportWebViewScreenState extends State<_ChatImportWebViewScreen>
    with SingleTickerProviderStateMixin {
  late final WebViewController _controller;
  String _status = 'Scanning conversation…';
  bool _finished = false;
  late final AnimationController _anim;
  bool _extracting = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            if (!mounted || _finished) return;
            setState(() {
              _status =
                  'Page loaded. Scroll if needed, then tap Capture to continue.';
            });
          },
          onWebResourceError: (error) {
            assert(() {
              print('[ChatWebViewImporter] Web resource error for '
                  '${widget.provider.name}: ${error.errorCode} '
                  '${error.description}');
              return true;
            }());
          },
        ),
      )
      // Use a mobile Chrome-like user agent so that providers treat this
      // WebView closer to a normal browser tab.
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/119.0.0.0 Mobile Safari/537.36',
      )
      ..loadRequest(Uri.parse(widget.initialUrl));

    // Soft timeout: after 25s, nudge the user instead of closing the screen.
    Future.delayed(const Duration(seconds: 25), () {
      if (!mounted || _finished) return;
      setState(() {
        _status =
            'If the page looks loaded, tap Capture below to import this chat.';
      });
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _runExtraction() async {
    if (_extracting || _finished) return;
    if (_finished) return;
    setState(() {
      _extracting = true;
      _status = 'Extracting messages…';
    });

    try {
      assert(() {
        print('[ChatWebViewImporter] Running JS extraction for '
            '${widget.provider.name} at ${DateTime.now()}');
        return true;
      }());
      final js = _buildExtractionScript(widget.provider);
      final raw = await _controller.runJavaScriptReturningResult(js);
      var jsonString = raw is String ? raw : raw?.toString() ?? '';
      assert(() {
        final preview = jsonString.length > 180
            ? jsonString.substring(0, 180)
            : jsonString;
        print('[ChatWebViewImporter] JS returned string of length '
            '${jsonString.length} for ${widget.provider.name}. Preview: '
            '$preview');
        return true;
      }());
      if (jsonString.isEmpty) {
        if (!_finished && mounted) {
          _finished = true;
          Navigator.of(context).pop<List<ImportedMessage>>(null);
        }
        return;
      }

      dynamic decoded;
      try {
        decoded = jsonDecode(jsonString);
        if (decoded is String) {
          assert(() {
            print('[ChatWebViewImporter] jsonDecode produced a String for '
                '${widget.provider.name}, attempting second-level decode.');
            return true;
          }());
          decoded = jsonDecode(decoded);
        }
      } catch (e1) {
        assert(() {
          print('[ChatWebViewImporter] jsonDecode failed for '
              '${widget.provider.name}: $e1');
          return true;
        }());
        decoded = null;
      }

      if (decoded is! List) {
        // As a last resort, treat the returned string as raw text and turn it
        // into alternating user/assistant chunks.
        final text = jsonString.trim();
        if (text.isEmpty) {
          if (!_finished && mounted) {
            _finished = true;
            Navigator.of(context).pop<List<ImportedMessage>>(null);
          }
          return;
        }
        final parts = text
            .split(RegExp(r'\n{2,}'))
            .map((p) => p.trim())
            .where((p) => p.isNotEmpty)
            .toList();
        final out = <ImportedMessage>[];
        var role = ImportedRole.user;
        for (var i = 0; i < parts.length && i < 40; i++) {
          out.add(ImportedMessage(
            id: 'wv_fallback_$i',
            role: role,
            text: parts[i],
            index: i,
          ));
          role = role == ImportedRole.user
              ? ImportedRole.assistant
              : ImportedRole.user;
        }
        assert(() {
          print('[ChatWebViewImporter] Using raw-text fallback with '
              '${out.length} messages for ${widget.provider.name}.');
          return true;
        }());
        if (!_finished && mounted) {
          _finished = true;
          Navigator.of(context).pop<List<ImportedMessage>>(
            out.isNotEmpty ? out : null,
          );
        }
        return;
      }
      final out = <ImportedMessage>[];
      var index = 0;
      for (final item in decoded) {
        if (item is! Map) continue;
        final roleStr = (item['role'] as String? ?? 'user').toLowerCase();
        final role = roleStr == 'assistant'
            ? ImportedRole.assistant
            : ImportedRole.user;
        final text = (item['text'] as String? ?? '').trim();
        if (text.isEmpty) continue;
        out.add(ImportedMessage(
          id: 'wv_${index}_$roleStr',
          role: role,
          text: text,
          index: index,
        ));
        index++;
        if (out.length >= 80) break;
      }
      assert(() {
        print('[ChatWebViewImporter] Decoded ${out.length} messages in '
            'WebView for ${widget.provider.name}.');
        return true;
      }());
      if (!_finished && mounted) {
        _finished = true;
        Navigator.of(context).pop<List<ImportedMessage>>(
          out.isNotEmpty ? out : null,
        );
      }
    } catch (e) {
      assert(() {
        print('[ChatWebViewImporter] JS extraction threw for '
            '${widget.provider.name}: $e');
        return true;
      }());
      if (!_finished && mounted) {
        _finished = true;
        Navigator.of(context).pop<List<ImportedMessage>>(null);
      }
    }
    if (mounted) {
      setState(() {
        _extracting = false;
      });
    }
  }

  String _buildExtractionScript(ChatProviderType provider) {
    // For now we only specialise for OpenAI/ChatGPT; other providers fall
    // back to a generic text-only DOM scrape.
    if (provider == ChatProviderType.openai) {
      return _chatGptExtractionScript;
    }
    return _genericExtractionScript;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: Column(
        children: [
          // Visible, fully interactive in-app browser for the shared chat.
          Expanded(
            child: WebViewWidget(controller: _controller),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: scheme.surface,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _status,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _extracting ? null : _runExtraction,
                      icon: _extracting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.camera_outlined),
                      label: Text(
                        _extracting
                            ? 'Capturing conversation…'
                            : 'Capture conversation for OMK',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const String _chatGptExtractionScript = r'''(function() {
  try {
    function getText(el) {
      if (!el) return '';
      return el.innerText || '';
    }
    // ChatGPT shared conversations at /s/... behave more like a static
    // article than a live chat UI. Prefer a DOM-based extraction that
    // uses structural hints (data-* attributes, class names) to infer
    // user/assistant roles, and only fall back to a plain text scrape
    // when no reliable containers are found.
    if (location && typeof location.pathname === 'string' &&
        location.pathname.indexOf('/s/') !== -1) {
      var shareRoot = document.querySelector('main') || document.body;
      if (!shareRoot) return '[]';

      function guessRoleFromText(text, index) {
        var t = (text || '').trim();
        if (!t) return 'assistant';
        var len = t.length;
        var lines = t.split(/\n+/g);
        var first = lines[0] || '';

        // Short questions / prompts are often user turns.
        if (len < 220 && /\?\s*$/.test(t)) return 'user';
        if (len < 260 && /^(I|We|I'm|We're|Bro|Hey|Ok|Okay)\b/i.test(first)) {
          return 'user';
        }

        // Bullet lists or long multi-paragraph text are more likely
        // assistant explanations.
        if (/^[\u2022\-]/.test(first) || lines.length > 3 || len > 400) {
          return 'assistant';
        }

        // Default: alternate, starting with assistant for these share
        // pages, which are usually model-led narratives.
        return (index % 2 === 0 ? 'assistant' : 'user');
      }

      // First attempt: find explicit chat turn containers inside <main>.
      var containerNodes = shareRoot.querySelectorAll(
        '[data-message-author-role], [data-message-author], [data-message-id], [data-testid^="conversation-turn-"]'
      );
      var domOut = [];
      for (var ci = 0; ci < containerNodes.length && domOut.length < 80; ci++) {
        var node = containerNodes[ci];
        var text = (node.innerText || '').trim();
        if (!text) continue;
        if (text.length < 8) continue;

        var role = 'assistant';
        var dataRole = (node.getAttribute('data-message-author-role') ||
                        node.getAttribute('data-message-author') || '').toLowerCase();
        if (dataRole.indexOf('user') !== -1) role = 'user';
        if (dataRole.indexOf('assistant') !== -1 || dataRole.indexOf('bot') !== -1) {
          role = 'assistant';
        }

        if (!dataRole) {
          var cls = (node.className || '').toString();
          if (/user|from-user|self|sender-user/i.test(cls)) {
            role = 'user';
          } else if (/assistant|bot|from-bot|gpt/i.test(cls)) {
            role = 'assistant';
          }
        }

        // As a final tie-breaker, fall back to content-based guess.
        var guessed = guessRoleFromText(text, domOut.length);
        if (!dataRole && (!node.className || node.className === '')) {
          role = guessed;
        }

        domOut.push({ role: role, text: text });
      }

      if (domOut.length >= 2) {
        return JSON.stringify(domOut);
      }

      // Fallback: treat <main> as a long article and segment by blank
      // lines, inferring roles from content.
      var shareText = (shareRoot.innerText || '').trim();
      if (!shareText) return '[]';
      var shareParts = shareText.split(/\n{2,}/g)
        .map(function(p) { return p.trim(); })
        .filter(function(p) { return p.length > 0; });
      var shareOut = [];
      for (var k = 0; k < shareParts.length && k < 80; k++) {
        var partText = shareParts[k];
        var roleGuess = guessRoleFromText(partText, k);
        shareOut.push({
          role: roleGuess,
          text: partText
        });
      }
      return JSON.stringify(shareOut);
    }

    // Fallback for non-share chat surfaces: use role-marked bubbles.
    var nodes = document.querySelectorAll('[data-message-author-role]');
    var out = [];
    for (var i = 0; i < nodes.length; i++) {
      var el = nodes[i];
      var role = (el.getAttribute('data-message-author-role') || 'user').toLowerCase();
      var text = getText(el).trim();
      if (!text) continue;
      out.push({ role: role, text: text });
    }

    if (out.length === 0) {
      return '[]';
    }

    return JSON.stringify(out);
  } catch (e) {
    return '[]';
  }
})();''' ;

const String _genericExtractionScript = r'''(function() {
  try {
    function guessRoleFromText(text, index) {
      var t = (text || '').trim();
      if (!t) return 'assistant';
      var len = t.length;
      var lines = t.split(/\n+/g);
      var first = lines[0] || '';

      if (len < 220 && /\?\s*$/.test(t)) return 'user';
      if (len < 260 && /^(I|We|I'm|We're|Bro|Hey|Ok|Okay)\b/i.test(first)) {
        return 'user';
      }

      if (/^[\u2022\-]/.test(first) || lines.length > 3 || len > 400) {
        return 'assistant';
      }

      return (index % 2 === 0 ? 'user' : 'assistant');
    }

    var root = document.querySelector('main') || document.body;
    if (!root) return '[]';

    // Try to find message-like containers first, using structural hints that
    // are common across many chat UIs (Gemini, Claude, Grok, Perplexity,
    // Copilot, DeepSeek, etc.).
    var selector = [
      '[data-message-author-role]',
      '[data-message-author]',
      '[data-message-id]',
      '[data-testid*="message"]',
      '[data-testid*="chat-message"]',
      '[class*="message"]'
    ].join(',');
    var nodes = root.querySelectorAll(selector);
    var out = [];
    for (var i = 0; i < nodes.length && out.length < 80; i++) {
      var el = nodes[i];
      var text = (el.innerText || '').trim();
      if (!text) continue;
      if (text.length < 6) continue;

      var role = 'assistant';
      var dataRole = (el.getAttribute('data-message-author-role') ||
                      el.getAttribute('data-message-author') || '').toLowerCase();
      if (dataRole.indexOf('user') !== -1 || dataRole.indexOf('human') !== -1) {
        role = 'user';
      }
      if (dataRole.indexOf('assistant') !== -1 ||
          dataRole.indexOf('model') !== -1 ||
          dataRole.indexOf('bot') !== -1) {
        role = 'assistant';
      }

      if (!dataRole) {
        var cls = (el.className || '').toString();
        if (/user|from-user|self|sender-user|you/i.test(cls)) {
          role = 'user';
        } else if (/assistant|bot|from-bot|gpt|ai|model/i.test(cls)) {
          role = 'assistant';
        }
      }

      if (!dataRole && (!el.className || el.className === '')) {
        role = guessRoleFromText(text, out.length);
      }

      out.push({ role: role, text: text });
    }

    if (out.length >= 2) {
      return JSON.stringify(out);
    }

    // Fallback: treat the page as a long article and segment into blocks,
    // inferring roles from content.
    var fullText = (root.innerText || '').trim();
    if (!fullText) return '[]';
    var parts = fullText.split(/\n{2,}/g)
      .map(function(p) { return p.trim(); })
      .filter(function(p) { return p.length > 0; });
    out = [];
    for (var j = 0; j < parts.length && j < 80; j++) {
      var partText = parts[j];
      out.push({
        role: guessRoleFromText(partText, j),
        text: partText
      });
    }
    return JSON.stringify(out);
  } catch (e) {
    return '[]';
  }
})();''';
