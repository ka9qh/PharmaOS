// شاشة عارض الروشتات الطبية المكبر وفحص خط الأطباء - PharmaOS Owner App
import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/models.dart';

class PrescriptionViewerScreen extends StatefulWidget {
  final OwnerTeleConsultation consultation;
  final VoidCallback onReplyRequested;

  const PrescriptionViewerScreen({
    super.key,
    required this.consultation,
    required this.onReplyRequested,
  });

  @override
  State<PrescriptionViewerScreen> createState() => _PrescriptionViewerScreenState();
}

class _PrescriptionViewerScreenState extends State<PrescriptionViewerScreen> {
  final TransformationController _transformationController = TransformationController();
  int _rotationQuarterTurns = 0;

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  void _rotateImage() {
    setState(() {
      _rotationQuarterTurns = (_rotationQuarterTurns + 1) % 4;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.consultation.title,
              style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold),
            ),
            Text(
              'المرسل: ${widget.consultation.pharmacistName}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.rotate_right_rounded, color: Colors.white),
            tooltip: 'تدوير الصورة',
            onPressed: _rotateImage,
          ),
          IconButton(
            icon: const Icon(Icons.restart_alt_rounded, color: Colors.white),
            tooltip: 'إعادة ضبط الحجم',
            onPressed: _resetZoom,
          ),
        ],
      ),
      body: widget.consultation.imageBase64 == null
          ? const Center(child: Text('لا توجد صورة روشتة مرفقة', style: TextStyle(color: Colors.white)))
          : Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    transformationController: _transformationController,
                    minScale: 0.5,
                    maxScale: 8.0,
                    boundaryMargin: const EdgeInsets.all(40),
                    child: RotatedBox(
                      quarterTurns: _rotationQuarterTurns,
                      child: Image.memory(
                        base64Decode(widget.consultation.imageBase64!),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),

                // شريط التوجيه والرد السريع السفلي
                Positioned(
                  bottom: 24,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withOpacity(0.92),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('إصدار التوجيه للصيدلي', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                              Text(
                                widget.consultation.notes ?? 'تكبير الروشتة وقراءة الأصناف بدقة',
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.edit_note_rounded, size: 18),
                          label: const Text('كتابة الرد ✍️'),
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onReplyRequested();
                          },
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
