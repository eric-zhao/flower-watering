import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../i18n/strings.dart';
import '../services/plant_repository.dart';

class AddPlantScreen extends StatefulWidget {
  const AddPlantScreen({super.key, required this.repository});

  final PlantRepository repository;

  @override
  State<AddPlantScreen> createState() => _AddPlantScreenState();
}

class _AddPlantScreenState extends State<AddPlantScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _freqCtrl = TextEditingController(text: '7');
  final _picker = ImagePicker();

  Uint8List _imageBytes = Uint8List(0);
  bool _picking = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _freqCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFrom(ImageSource source) async {
    Navigator.of(context).pop();
    setState(() => _picking = true);
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() => _imageBytes = bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.pickerError(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _openPickerSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(S.chooseFromGallery),
              onTap: () => _pickFrom(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: Text(S.takeAPhoto),
              onTap: () => _pickFrom(ImageSource.camera),
            ),
            if (_imageBytes.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(S.removePhoto),
                onTap: () {
                  Navigator.of(ctx).pop();
                  setState(() => _imageBytes = Uint8List(0));
                },
              ),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    widget.repository.create(
      name: _nameCtrl.text.trim(),
      imageBytes: _imageBytes,
      frequencyDays: int.parse(_freqCtrl.text.trim()),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.addPlant)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PhotoPickerBox(
                bytes: _imageBytes,
                busy: _picking,
                onTap: _openPickerSheet,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameCtrl,
                maxLength: 40,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: S.plantName,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return S.required;
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _freqCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: S.waterEveryDays,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  final n = int.tryParse(v?.trim() ?? '');
                  if (n == null) return S.enterANumber;
                  if (n < 1 || n > 365) return S.between1And365;
                  return null;
                },
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: Text(S.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoPickerBox extends StatelessWidget {
  const _PhotoPickerBox({
    required this.bytes,
    required this.busy,
    required this.onTap,
  });

  final Uint8List bytes;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade200),
        ),
        clipBehavior: Clip.antiAlias,
        child: busy
            ? const Center(child: CircularProgressIndicator())
            : bytes.isNotEmpty
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(bytes, fit: BoxFit.cover),
                      const Positioned(
                        right: 8,
                        bottom: 8,
                        child: Material(
                          color: Colors.black54,
                          shape: CircleBorder(),
                          child: Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.edit,
                                size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined,
                          size: 48, color: Colors.green.shade400),
                      const SizedBox(height: 8),
                      Text(
                        S.tapToAddPhoto,
                        style: TextStyle(color: Colors.green.shade700),
                      ),
                    ],
                  ),
      ),
    );
  }
}
