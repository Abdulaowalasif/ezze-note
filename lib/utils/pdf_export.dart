import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/note.dart';

class PdfExportService {
  static Future<void> exportNote(
      Note note,
      Map<String, List<Map<String, dynamic>>> canvasTexts,
      BuildContext context
      ) async {

    // 1. LOAD COMPREHENSIVE FONTS
    // Roboto for standard text
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    // Noto Sans Symbols handles monochrome symbols (like arrows, math)
    final symbolFont = await PdfGoogleFonts.notoSansSymbolsRegular();

    // Noto Color Emoji is essential for actual emojis
    final emojiFont = await PdfGoogleFonts.notoColorEmoji();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: fontRegular,
        bold: fontBold,
        // CRITICAL: We list fallback fonts here.
        // If a character isn't in Roboto, it checks Symbols, then Emoji.
        fontFallback: [symbolFont, emojiFont],
      ),
    );

    // ── COVER PAGE ──────────────────────────────────────────────────────────
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (ctx) => pw.FullPage(
          ignoreMargins: true,
          child: pw.Container(
            color: PdfColor.fromHex(_colorToHex(note.coverColor)),
            child: pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  if (note.coverEmoji != null)
                    pw.Text(
                        note.coverEmoji!,
                        style: pw.TextStyle(fontSize: 64, fontFallback: [emojiFont])
                    ),
                  pw.SizedBox(height: 24),
                  pw.Text(
                    note.title.isEmpty ? 'Untitled' : note.title,
                    style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // ── CONTENT PAGES ────────────────────────────────────────────────────────
    for (int i = 0; i < note.pages.length; i++) {
      final page = note.pages[i];
      final pageLabels = canvasTexts[page.id] ?? [];

      final List<pw.Widget> imageWidgets = [];
      for (final img in page.images) {
        final file = File(img.path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          imageWidgets.add(
            pw.Positioned(
              left: img.x,
              top: img.y,
              child: pw.ClipRRect(
                horizontalRadius: 10, verticalRadius: 10,
                child: pw.Image(pw.MemoryImage(bytes), width: img.width, height: img.height, fit: pw.BoxFit.cover),
              ),
            ),
          );
        }
      }

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (ctx) {
            return pw.Stack(
              children: [
                // LAYER 1: DRAWINGS
                if (page.drawings.isNotEmpty)
                  pw.Positioned.fill(
                    child: pw.CustomPaint(
                      painter: (canvas, size) {
                        for (final drawnPoint in page.drawings) {
                          if (drawnPoint.points.isEmpty || drawnPoint.isEraser) continue;
                          canvas.setStrokeColor(PdfColor.fromHex(_colorToHex(drawnPoint.color)));
                          canvas.setLineWidth(drawnPoint.strokeWidth);
                          canvas.setLineJoin(PdfLineJoin.round);
                          canvas.setLineCap(PdfLineCap.round);
                          final first = drawnPoint.points.first;
                          canvas.moveTo(first.dx, size.y - first.dy);
                          for (final point in drawnPoint.points) {
                            canvas.lineTo(point.dx, size.y - point.dy);
                          }
                          canvas.strokePath();
                        }
                      },
                    ),
                  ),

                // LAYER 2: MAIN PAGE TEXT (With Emoji Support)
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Align(
                      alignment: pw.Alignment.topRight,
                      child: pw.Text('${i + 1}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500)),
                    ),
                    pw.SizedBox(height: 10),
                    if (page.textContent.isNotEmpty)
                      pw.Text(
                        page.textContent,
                        style: pw.TextStyle(
                          fontSize: 14,
                          lineSpacing: 6,
                          // Forces the text to look for emojis if standard fonts fail
                          fontFallback: [emojiFont, symbolFont],
                        ),
                      ),
                  ],
                ),

                // LAYER 3: DIALOG/CANVAS LABELS
                ...pageLabels.map((t) {
                  return pw.Positioned(
                    left: t['dx'] as double,
                    top: t['dy'] as double,
                    child: pw.Text(
                      t['text'] as String,
                      style: pw.TextStyle(
                        color: PdfColor.fromHex((t['color'] as int).toRadixString(16).padLeft(8, '0').substring(2)),
                        fontSize: t['size'] as double,
                        fontWeight: pw.FontWeight.bold,
                        fontFallback: [emojiFont, symbolFont],
                      ),
                    ),
                  );
                }).toList(),

                // LAYER 4: IMAGES & STICKIES
                ...imageWidgets,
                ...page.stickyNotes.map((sticky) => pw.Positioned(
                  left: sticky.x, top: sticky.y,
                  child: pw.Container(
                    width: 120, padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex(_colorToHex(sticky.color)),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text(
                        sticky.content,
                        style: pw.TextStyle(fontSize: 10, fontFallback: [emojiFont, symbolFont])
                    ),
                  ),
                )).toList(),
              ],
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(onLayout: (_) async => pdf.save(), name: '${note.title}.pdf');
  }

  static String _colorToHex(Color color) => color.value.toRadixString(16).padLeft(8, '0').substring(2);
}