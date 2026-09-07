import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

/// Keeps a user-selected local photo visible as a private comparison reference.
///
/// The selected bytes live only in memory for the current app session. They are
/// never uploaded, written into the bundled catalogue, or used to change the
/// identification score.
class LocalReferenceImageOverlay extends StatefulWidget {
  const LocalReferenceImageOverlay({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<LocalReferenceImageOverlay> createState() =>
      _LocalReferenceImageOverlayState();
}

class _LocalReferenceImageOverlayState
    extends State<LocalReferenceImageOverlay> {
  Uint8List? _imageBytes;
  String? _fileName;

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (!mounted || result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(l10n.localImageReadError)),
      );
      return;
    }

    setState(() {
      _imageBytes = bytes;
      _fileName = file.name;
    });
  }

  void _clearImage() {
    setState(() {
      _imageBytes = null;
      _fileName = null;
    });
  }

  Future<void> _showLargePreview() async {
    final bytes = _imageBytes;
    if (bytes == null) return;
    final l10n = AppLocalizations.of(context);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 760),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 6, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _fileName ?? l10n.localImageReference,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(dialogContext).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: MaterialLocalizations.of(dialogContext)
                          .closeButtonTooltip,
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 5,
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bytes = _imageBytes;

    return Stack(
      children: [
        widget.child,
        Positioned(
          right: 14,
          bottom: 76,
          child: SafeArea(
            minimum: const EdgeInsets.only(bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (bytes != null) ...[
                  Material(
                    elevation: 6,
                    borderRadius: BorderRadius.circular(14),
                    clipBehavior: Clip.antiAlias,
                    child: SizedBox(
                      width: 128,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: _showLargePreview,
                            child: AspectRatio(
                              aspectRatio: 4 / 3,
                              child: Image.memory(bytes, fit: BoxFit.cover),
                            ),
                          ),
                          ColoredBox(
                            color: AppTheme.creamStrong,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Text(
                                      l10n.localImageReference,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context).textTheme.labelSmall,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  tooltip: l10n.localImageRemove,
                                  onPressed: _clearImage,
                                  icon: const Icon(Icons.close, size: 18),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Material(
                  color: AppTheme.forest,
                  elevation: 6,
                  shape: const CircleBorder(),
                  child: Tooltip(
                    message: l10n.localImageChoose,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _pickImage,
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(
                          Icons.photo_library_outlined,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
