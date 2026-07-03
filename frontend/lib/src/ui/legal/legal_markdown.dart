import 'package:flutter/material.dart';

import '../nest_theme.dart';

/// 법무 문서(privacy.md / terms.md)용 경량 마크다운 렌더러.
///
/// 지원 문법(법무 문서에 필요한 최소 집합):
/// - `#`, `##`, `###` 제목
/// - 빈 줄로 구분되는 문단
/// - `- ` 불릿, `1.` 번호 목록
/// - `**굵게**` 인라인
/// - `| a | b |` 표(헤더 + 구분선 + 행)
/// - `<!-- ... -->` 주석은 렌더에서 제외
///
/// 새 pub 의존성을 추가하지 않기 위해 직접 구현한다.
class LegalMarkdown extends StatelessWidget {
  const LegalMarkdown(this.source, {super.key});

  final String source;

  @override
  Widget build(BuildContext context) {
    final blocks = _parseBlocks(source);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in blocks) _buildBlock(context, block),
      ],
    );
  }

  Widget _buildBlock(BuildContext context, _Block block) {
    final theme = Theme.of(context);
    switch (block.type) {
      case _BlockType.h1:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            block.text,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: NestColors.deepWood,
            ),
          ),
        );
      case _BlockType.h2:
        return Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Text(
            block.text,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: NestColors.deepWood,
            ),
          ),
        );
      case _BlockType.h3:
        return Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text(
            block.text,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: NestColors.clay,
            ),
          ),
        );
      case _BlockType.paragraph:
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _richText(context, block.text),
        );
      case _BlockType.bullet:
        return _listItem(context, block.text, marker: '•');
      case _BlockType.numbered:
        return _listItem(context, block.text, marker: '${block.ordinal}.');
      case _BlockType.table:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: _buildTable(context, block.rows!),
        );
    }
  }

  Widget _listItem(BuildContext context, String text, {required String marker}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Text(
              marker,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: NestColors.clay,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Expanded(child: _richText(context, text)),
        ],
      ),
    );
  }

  Widget _buildTable(BuildContext context, List<List<String>> rows) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: NestColors.roseMist),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        border: TableBorder.symmetric(
          inside: BorderSide(color: NestColors.roseMist.withValues(alpha: 0.7)),
        ),
        columnWidths: const {0: IntrinsicColumnWidth()},
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          for (var i = 0; i < rows.length; i++)
            TableRow(
              decoration: BoxDecoration(
                color: i == 0
                    ? NestColors.roseMist.withValues(alpha: 0.35)
                    : null,
              ),
              children: [
                for (final cell in rows[i])
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: _richText(
                      context,
                      cell,
                      bold: i == 0,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  /// `**굵게**`를 지원하는 인라인 텍스트.
  Widget _richText(BuildContext context, String text, {bool bold = false}) {
    final baseStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          height: 1.55,
          color: NestColors.deepWood.withValues(alpha: 0.9),
          fontWeight: bold ? FontWeight.w700 : null,
        );
    return Text.rich(
      TextSpan(children: _inlineSpans(text, baseStyle)),
    );
  }

  List<TextSpan> _inlineSpans(String text, TextStyle? baseStyle) {
    final spans = <TextSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*');
    var index = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > index) {
        spans.add(TextSpan(text: text.substring(index, match.start), style: baseStyle));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: baseStyle?.copyWith(fontWeight: FontWeight.w800),
      ));
      index = match.end;
    }
    if (index < text.length) {
      spans.add(TextSpan(text: text.substring(index), style: baseStyle));
    }
    return spans;
  }

  List<_Block> _parseBlocks(String markdown) {
    final lines = markdown.replaceAll('\r\n', '\n').split('\n');
    final blocks = <_Block>[];
    final paragraph = <String>[];
    var numberedCounter = 0;
    var inComment = false;

    void flushParagraph() {
      if (paragraph.isEmpty) return;
      blocks.add(_Block(_BlockType.paragraph, paragraph.join(' ')));
      paragraph.clear();
    }

    for (var i = 0; i < lines.length; i++) {
      final raw = lines[i];
      final line = raw.trimRight();
      final trimmed = line.trim();

      // HTML 주석 스킵 (여러 줄 지원)
      if (inComment) {
        if (trimmed.contains('-->')) inComment = false;
        continue;
      }
      if (trimmed.startsWith('<!--')) {
        if (!trimmed.contains('-->')) inComment = true;
        continue;
      }

      if (trimmed.isEmpty) {
        flushParagraph();
        numberedCounter = 0;
        continue;
      }

      // 표: | a | b |
      if (trimmed.startsWith('|') && trimmed.endsWith('|')) {
        flushParagraph();
        final rows = <List<String>>[];
        var j = i;
        while (j < lines.length &&
            lines[j].trim().startsWith('|') &&
            lines[j].trim().endsWith('|')) {
          final cells = lines[j]
              .trim()
              .split('|')
              .where((c) => c.isNotEmpty || true)
              .toList();
          // 앞뒤 빈 요소 제거
          cells.removeAt(0);
          cells.removeLast();
          final cleaned = cells.map((c) => c.trim()).toList();
          // 구분선(---) 행은 건너뛴다.
          final isDivider = cleaned.every((c) => RegExp(r'^:?-{2,}:?$').hasMatch(c));
          if (!isDivider) rows.add(cleaned);
          j++;
        }
        blocks.add(_Block.table(rows));
        i = j - 1;
        continue;
      }

      if (trimmed.startsWith('### ')) {
        flushParagraph();
        blocks.add(_Block(_BlockType.h3, trimmed.substring(4)));
      } else if (trimmed.startsWith('## ')) {
        flushParagraph();
        blocks.add(_Block(_BlockType.h2, trimmed.substring(3)));
      } else if (trimmed.startsWith('# ')) {
        flushParagraph();
        blocks.add(_Block(_BlockType.h1, trimmed.substring(2)));
      } else if (trimmed.startsWith('- ')) {
        flushParagraph();
        blocks.add(_Block(_BlockType.bullet, trimmed.substring(2)));
      } else if (RegExp(r'^\d+\.\s').hasMatch(trimmed)) {
        flushParagraph();
        numberedCounter++;
        final text = trimmed.replaceFirst(RegExp(r'^\d+\.\s'), '');
        blocks.add(_Block(_BlockType.numbered, text, ordinal: numberedCounter));
      } else {
        paragraph.add(trimmed);
      }
    }
    flushParagraph();
    return blocks;
  }
}

enum _BlockType { h1, h2, h3, paragraph, bullet, numbered, table }

class _Block {
  _Block(this.type, this.text, {this.ordinal = 0}) : rows = null;
  _Block.table(this.rows)
      : type = _BlockType.table,
        text = '',
        ordinal = 0;

  final _BlockType type;
  final String text;
  final int ordinal;
  final List<List<String>>? rows;
}
