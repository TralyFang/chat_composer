import 'package:flutter/widgets.dart';

import 'models.dart';

/// 管理已确认的 @ token。手打 `@xxx` 只是普通字符，不会写成 mention。
/// [maxMentions] 为 1 时仅限一人，后一次覆盖前一次；为 null 时不限制人数。
class MentionEditingController extends TextEditingController {
  MentionEditingController({super.text, int? maxMentions}) : _maxMentions = maxMentions;

  final List<_MentionMark> _mentions = [];
  int? _maxMentions;
  bool _mutating = false;
  bool _highlightMentions = true;
  TextStyle _highlightStyle = const TextStyle(
    color: Color(0xFF3DFFB0),
    fontWeight: FontWeight.w600,
  );

  bool get highlightMentions => _highlightMentions;

  TextStyle get highlightStyle => _highlightStyle;

  void applyHighlight({required bool enabled, TextStyle? style}) {
    final nextStyle = style ?? _highlightStyle;
    if (_highlightMentions == enabled && nextStyle == _highlightStyle) return;
    _highlightMentions = enabled;
    _highlightStyle = nextStyle;
    notifyListeners();
  }

  /// mention 增删时通知外层同步 [ChatComposerController]。
  VoidCallback? onMentionChanged;

  /// null 表示不限制。小于 1 会当成 1。
  int? get maxMentions => _maxMentions;

  set maxMentions(int? value) {
    if (value != null && value < 1) value = 1;
    if (_maxMentions == value) return;
    _maxMentions = value;
    if (_enforceLimit()) onMentionChanged?.call();
  }

  List<MentionTarget> get mentions => [for (final mark in _mentions) mark.target];

  /// 第一个原子 token 在输入框全文中的起始下标。
  int get mentionStart => _mentions.isEmpty ? 0 : _mentions.first.start;

  String get token => _mentions.isEmpty ? '' : _mentions.first.token;

  void insertMention(MentionTarget user) {
    final existing = _mentions.indexWhere((mark) => mark.target.userId == user.userId);
    if (existing >= 0) {
      _placeCaret(_mentions[existing].end);
      return;
    }

    if (_maxMentions == 1 && _mentions.isNotEmpty) {
      final mark = _mentions.first;
      final nextText = text.replaceRange(mark.start, mark.end, user.token);
      _mentions
        ..clear()
        ..add(_MentionMark(user, mark.start));
      _commit(
        nextText,
        mark.start + user.token.length,
        notify: true,
      );
      return;
    }

    if (_maxMentions != null && _mentions.length >= _maxMentions!) {
      _removeMarkAt(0);
    }

    final sel = selection;
    var start = sel.isValid ? sel.start : text.length;
    var end = sel.isValid ? sel.end : text.length;
    if (start > end) {
      final swap = start;
      start = end;
      end = swap;
    }
    final expanded = _expandToTokens(start, end);
    start = expanded.$1;
    end = expanded.$2;

    final nextToken = user.token;
    final nextText = text.replaceRange(start, end, nextToken);
    final delta = nextToken.length - (end - start);
    _mentions.removeWhere((mark) => start < mark.end && end > mark.start);
    for (final mark in _mentions) {
      if (mark.start >= end) mark.start += delta;
    }
    _mentions.add(_MentionMark(user, start));
    _sort();
    _commit(nextText, start + nextToken.length, notify: true);
  }

  void clearMention({bool removeToken = true}) {
    if (_mentions.isEmpty) return;
    if (!removeToken) {
      _mentions.clear();
      onMentionChanged?.call();
      return;
    }
    var next = text;
    for (final mark in _mentions.reversed) {
      if (!_tokenAt(next, mark.start, mark.token)) continue;
      next = next.replaceRange(mark.start, mark.end, '');
    }
    _mentions.clear();
    _commit(next, 0, notify: true);
  }

  void resetText() {
    final had = _mentions.isNotEmpty;
    _mentions.clear();
    _commit('', 0, notify: had);
  }

  @override
  set value(TextEditingValue newValue) {
    if (_mutating) {
      super.value = newValue;
      return;
    }
    if (_mentions.isEmpty) {
      super.value = _sanitize(newValue);
      return;
    }

    final droppedInvalid = _dropInvalid();
    if (_mentions.isEmpty) {
      super.value = _sanitize(newValue);
      if (droppedInvalid) onMentionChanged?.call();
      return;
    }

    final oldText = text;
    final nextText = newValue.text;
    if (nextText == oldText) {
      super.value = _clampSelection(_sanitize(newValue));
      return;
    }

    final diff = _textDiff(oldText, nextText);
    final hit = _mentions.where((mark) => diff.oldStart < mark.end && diff.oldEnd > mark.start).toList();
    if (hit.isEmpty) {
      final delta = (diff.newEnd - diff.newStart) - (diff.oldEnd - diff.oldStart);
      for (final mark in _mentions) {
        if (diff.oldEnd <= mark.start) mark.start += delta;
      }
      if (_allTokensMatch(nextText)) {
        super.value = _clampSelection(_sanitize(newValue));
        return;
      }
      _mentions.clear();
      super.value = _sanitize(newValue);
      onMentionChanged?.call();
      return;
    }

    var leftEnd = diff.oldStart;
    var rightStart = diff.oldEnd;
    for (final mark in hit) {
      if (mark.start < leftEnd) leftEnd = mark.start;
      if (mark.end > rightStart) rightStart = mark.end;
    }
    final left = oldText.substring(0, leftEnd);
    final right = oldText.substring(rightStart);
    final inserted = nextText.substring(diff.newStart, diff.newEnd);
    final merged = '$left$inserted$right';
    final cursor = (left.length + inserted.length).clamp(0, merged.length);
    final shiftAfter = inserted.length - (rightStart - leftEnd);
    _mentions.removeWhere(hit.contains);
    for (final mark in _mentions) {
      if (mark.start >= rightStart) mark.start += shiftAfter;
    }
    final removed = _dropInvalid(source: merged);
    _sort();
    super.value = TextEditingValue(
      text: merged,
      selection: TextSelection.collapsed(offset: cursor),
      composing: TextRange.empty,
    );
    if (hit.isNotEmpty || removed) onMentionChanged?.call();
  }

  bool _enforceLimit() {
    if (_maxMentions == null || _mentions.length <= _maxMentions!) return false;
    while (_mentions.length > _maxMentions!) {
      _removeMarkAt(0);
    }
    return true;
  }

  void _removeMarkAt(int index) {
    final mark = _mentions[index];
    final next = text.replaceRange(mark.start, mark.end, '');
    final removedLen = mark.end - mark.start;
    var caret = selection.isValid ? selection.extentOffset : next.length;
    if (caret >= mark.end) {
      caret -= removedLen;
    } else if (caret > mark.start) {
      caret = mark.start;
    }
    _mentions.removeAt(index);
    for (final other in _mentions) {
      if (other.start >= mark.end) other.start -= removedLen;
    }
    _commit(next, caret.clamp(0, next.length), notify: false);
  }

  (int, int) _expandToTokens(int start, int end) {
    var changed = true;
    while (changed) {
      changed = false;
      for (final mark in _mentions) {
        if (start < mark.end && end > mark.start) {
          if (mark.start < start) {
            start = mark.start;
            changed = true;
          }
          if (mark.end > end) {
            end = mark.end;
            changed = true;
          }
        }
      }
    }
    return (start, end);
  }

  void _placeCaret(int offset) {
    _commit(text, offset.clamp(0, text.length), notify: false);
  }

  void _commit(String nextText, int caret, {required bool notify}) {
    _mutating = true;
    value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: caret.clamp(0, nextText.length)),
      composing: TextRange.empty,
    );
    _mutating = false;
    if (notify) onMentionChanged?.call();
  }

  bool _dropInvalid({String? source}) {
    final from = source ?? text;
    final before = _mentions.length;
    _mentions.removeWhere((mark) => !_tokenAt(from, mark.start, mark.token));
    return _mentions.length != before;
  }

  bool _allTokensMatch(String source) {
    for (final mark in _mentions) {
      if (!_tokenAt(source, mark.start, mark.token)) return false;
    }
    return true;
  }

  void _sort() {
    _mentions.sort((a, b) => a.start.compareTo(b.start));
  }

  bool _tokenAt(String source, int start, String token) {
    if (token.isEmpty || start < 0 || start + token.length > source.length) {
      return false;
    }
    return source.substring(start, start + token.length) == token;
  }

  ({int oldStart, int oldEnd, int newStart, int newEnd}) _textDiff(
    String oldText,
    String newText,
  ) {
    var prefix = 0;
    final oldLen = oldText.length;
    final newLen = newText.length;
    final minLen = oldLen < newLen ? oldLen : newLen;
    while (prefix < minLen && oldText.codeUnitAt(prefix) == newText.codeUnitAt(prefix)) {
      prefix++;
    }
    var suffix = 0;
    while (suffix < oldLen - prefix &&
        suffix < newLen - prefix &&
        oldText.codeUnitAt(oldLen - 1 - suffix) == newText.codeUnitAt(newLen - 1 - suffix)) {
      suffix++;
    }
    return (
      oldStart: prefix,
      oldEnd: oldLen - suffix,
      newStart: prefix,
      newEnd: newLen - suffix,
    );
  }

  TextEditingValue _clampSelection(TextEditingValue next) {
    final sel = next.selection;
    if (!sel.isValid) return next;
    final length = next.text.length;
    final base = _snapOffset(sel.baseOffset, length);
    final extent = _snapOffset(sel.extentOffset, length);
    final composing = next.composing;
    final composingHits = composing.isValid &&
        !composing.isCollapsed &&
        _mentions.any((mark) => composing.start < mark.end && composing.end > mark.start);
    if (base == sel.baseOffset && extent == sel.extentOffset && !composingHits) {
      return next;
    }
    // composing 落在 token 内时先结束合成，避免和输入法抢文本。
    return next.copyWith(
      selection: TextSelection(baseOffset: base, extentOffset: extent),
      composing: composingHits ? TextRange.empty : composing,
    );
  }

  int _snapOffset(int offset, int length) {
    if (offset < 0) return 0;
    if (offset > length) return length;
    for (final mark in _mentions) {
      if (offset > mark.start && offset < mark.end) {
        final distToStart = offset - mark.start;
        final distToEnd = mark.end - offset;
        return distToStart <= distToEnd ? mark.start : mark.end;
      }
    }
    return offset;
  }

  TextEditingValue _sanitize(TextEditingValue next) {
    if (next.selection.isValid) return next;
    return next.copyWith(
      selection: TextSelection.collapsed(offset: next.text.length),
    );
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (_mentions.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final mentionStyle = _highlightMentions
        ? (style ?? const TextStyle()).merge(_highlightStyle)
        : style;
    final children = <InlineSpan>[];
    var cursor = 0;
    for (final mark in _mentions) {
      if (!_tokenAt(text, mark.start, mark.token)) continue;
      if (mark.start > cursor) {
        _appendSlice(children, text.substring(cursor, mark.start), cursor, style, withComposing);
      }
      children.add(TextSpan(text: mark.token, style: mentionStyle));
      cursor = mark.end;
    }
    if (cursor < text.length) {
      _appendSlice(children, text.substring(cursor), cursor, style, withComposing);
    }
    if (children.isEmpty) {
      return TextSpan(text: '', style: style);
    }
    return TextSpan(style: style, children: children);
  }

  void _appendSlice(
    List<InlineSpan> children,
    String slice,
    int base,
    TextStyle? style,
    bool withComposing,
  ) {
    if (slice.isEmpty) return;
    final composing = value.composing;
    if (!withComposing || !composing.isValid || composing.isCollapsed) {
      children.add(TextSpan(text: slice, style: style));
      return;
    }
    final sliceEnd = base + slice.length;
    final cStart = composing.start < base ? base : composing.start;
    final cEnd = composing.end > sliceEnd ? sliceEnd : composing.end;
    if (cStart >= cEnd || cStart >= sliceEnd || cEnd <= base) {
      children.add(TextSpan(text: slice, style: style));
      return;
    }
    final localStart = cStart - base;
    final localEnd = cEnd - base;
    final composingStyle = (style ?? const TextStyle()).merge(
      const TextStyle(decoration: TextDecoration.underline),
    );
    if (localStart > 0) {
      children.add(TextSpan(text: slice.substring(0, localStart), style: style));
    }
    children.add(TextSpan(
      text: slice.substring(localStart, localEnd),
      style: composingStyle,
    ));
    if (localEnd < slice.length) {
      children.add(TextSpan(text: slice.substring(localEnd), style: style));
    }
  }
}

class _MentionMark {
  _MentionMark(this.target, this.start);

  final MentionTarget target;
  int start;

  String get token => target.token;

  int get end => start + token.length;
}
