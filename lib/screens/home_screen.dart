import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/project_provider.dart';
import '../providers/editor_provider.dart';


// ─── Color Palette (matches reference) ────────────────────────────────────────
const _kBg = Color(0xFF1A1C14);
const _kCard = Color(0xFF2A2C22);
const _kAccent = Color(0xFFD4C462);

const _kTextPrimary = Color(0xFFF5F0E0);
const _kTextSecondary = Color(0xFF8A8A78);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tabIndex = 0;
  final _tabs = ['Last Works', 'Export'];

  // ── New Project Flow ──────────────────────────────────────────────────────
  void _showNewProjectMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          Text('New Project', style: GoogleFonts.outfit(color: _kTextPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          _menuTile(Icons.videocam_rounded, 'Video Edit', 'Multi-track video editing', () { Navigator.pop(context); _askProjectName('video'); }),
          const SizedBox(height: 12),
          _menuTile(Icons.audiotrack_rounded, 'Audio Mix', 'Professional audio mixing', () { Navigator.pop(context); _askProjectName('audio'); }),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ]),
      ),
    );
  }

  Widget _menuTile(IconData icon, String title, String sub, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white10)),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _kAccent.withValues(alpha: 0.15), shape: BoxShape.circle), child: Icon(icon, color: _kAccent, size: 24)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.outfit(color: _kTextPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
            Text(sub, style: GoogleFonts.outfit(color: _kTextSecondary, fontSize: 12)),
          ])),
          const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
        ]),
      ),
    );
  }

  void _askProjectName(String type) {
    final controller = TextEditingController(text: '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Project Name', style: GoogleFonts.outfit(color: _kTextPrimary, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: GoogleFonts.outfit(color: _kTextPrimary),
          decoration: InputDecoration(
            hintText: type == 'video' ? 'My Video Project' : 'My Audio Mix',
            hintStyle: GoogleFonts.outfit(color: _kTextSecondary),
            filled: true, fillColor: _kBg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kAccent)),
          ),
          onSubmitted: (_) => _createAndNavigate(ctx, controller, type),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.outfit(color: _kTextSecondary))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _kAccent, foregroundColor: _kBg),
            onPressed: () => _createAndNavigate(ctx, controller, type),
            child: Text('Create', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _createAndNavigate(BuildContext ctx, TextEditingController ctrl, String type) async {
    final name = ctrl.text.trim().isEmpty ? (type == 'video' ? 'Untitled Video' : 'Untitled Audio') : ctrl.text.trim();
    Navigator.pop(ctx);
    final project = ref.read(projectsProvider.notifier).createProject(name, type);
    if (type == 'video') {
      await ref.read(editorProvider.notifier).loadProject(project.id);
      if (mounted) context.push('/video-editor');
    } else {
      await ref.read(audioEditorProvider.notifier).loadProject(project.id);
      if (mounted) context.push('/audio-editor');
    }
  }

  // ── Project Actions ───────────────────────────────────────────────────────
  void _showProjectMenu(Project project) {
    showModalBottomSheet(
      context: context, backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(project.name, style: GoogleFonts.outfit(color: _kTextPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.image_outlined, color: _kAccent), title: Text('Set Thumbnail', style: GoogleFonts.outfit(color: _kTextPrimary)),
            onTap: () { Navigator.pop(context); _setThumbnail(project); },
          ),
          ListTile(
            leading: const Icon(Icons.edit, color: _kAccent), title: Text('Rename', style: GoogleFonts.outfit(color: _kTextPrimary)),
            onTap: () { Navigator.pop(context); _renameProject(project); },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.redAccent), title: Text('Delete', style: GoogleFonts.outfit(color: Colors.redAccent)),
            onTap: () { Navigator.pop(context); _deleteProject(project); },
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ]),
      ),
    );
  }

  Future<void> _setThumbnail(Project project) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      ref.read(projectsProvider.notifier).updateThumbnail(project.id, image.path);
    }
  }

  void _renameProject(Project project) {
    final ctrl = TextEditingController(text: project.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Rename', style: GoogleFonts.outfit(color: _kTextPrimary, fontWeight: FontWeight.bold)),
        content: TextField(controller: ctrl, autofocus: true, style: GoogleFonts.outfit(color: _kTextPrimary),
          decoration: InputDecoration(filled: true, fillColor: _kBg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kAccent)))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.outfit(color: _kTextSecondary))),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: _kAccent, foregroundColor: _kBg),
            onPressed: () { Navigator.pop(ctx); if (ctrl.text.trim().isNotEmpty) { ref.read(projectsProvider.notifier).renameProject(project.id, ctrl.text.trim()); } },
            child: Text('Save', style: GoogleFonts.outfit(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  void _deleteProject(Project project) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete "${project.name}"?', style: GoogleFonts.outfit(color: _kTextPrimary, fontWeight: FontWeight.bold)),
        content: Text('This cannot be undone.', style: GoogleFonts.outfit(color: _kTextSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.outfit(color: _kTextSecondary))),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () { Navigator.pop(ctx); ref.read(projectsProvider.notifier).deleteProject(project.id); },
            child: Text('Delete', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white))),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final projectsState = ref.watch(projectsProvider);
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: _kBg,
      body: Column(children: [
        // ── Top Bar ───────────────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(20, topPad + 16, 20, 0),
          child: Row(
            children: [
              // Plus button
              GestureDetector(
                onTap: _showNewProjectMenu,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: _kAccent,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '+',
                    style: TextStyle(
                      color: _kBg,
                      fontSize: 32,
                      fontWeight: FontWeight.w300,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              // Download Button
              GestureDetector(
                onTap: () => context.push('/download'),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _kCard,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white10),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.download_rounded,
                    color: _kTextPrimary,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Title ─────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          child: Align(
            alignment: Alignment.centerLeft,
            child: RichText(
              text: TextSpan(children: [
                TextSpan(
                  text: 'Create\n',
                  style: GoogleFonts.caveat(color: Colors.white, fontSize: 64, fontWeight: FontWeight.w600, height: 1.1),
                ),
                TextSpan(
                  text: 'and ',
                  style: GoogleFonts.caveat(color: Colors.white, fontSize: 64, fontWeight: FontWeight.w400, height: 1.1),
                ),
                TextSpan(
                  text: 'make',
                  style: GoogleFonts.caveat(color: Colors.white, fontSize: 64, fontWeight: FontWeight.w700, height: 1.1),
                ),
              ]),
            ),
          ),
        ),

        // ── Tab Chips ─────────────────────────────────────────────────────
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _tabs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => setState(() => _tabIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: _tabIndex == i ? Colors.white : const Color(0xFF333527),
                  borderRadius: BorderRadius.circular(24),
                ),
                alignment: Alignment.center,
                child: Text(
                  _tabs[i],
                  style: GoogleFonts.outfit(
                    color: _tabIndex == i ? Colors.black : Colors.white70,
                    fontSize: 15,
                    fontWeight: _tabIndex == i ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // ── Content ───────────────────────────────────────────────────────
        Expanded(child: _buildTabContent(projectsState)),
      ]),
    );
  }

  Widget _buildTabContent(ProjectsState state) {
    if (_tabIndex == 0) return _buildLastWorks(state);
    return _buildPlaceholderTab('Export presets coming soon');
  }

  Widget _buildPlaceholderTab(String msg) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.construction_rounded, color: _kTextSecondary.withValues(alpha: 0.3), size: 64),
      const SizedBox(height: 16),
      Text(msg, style: GoogleFonts.outfit(color: _kTextSecondary, fontSize: 14)),
    ]));
  }

  // ── Last Works ────────────────────────────────────────────────────────────
  Widget _buildLastWorks(ProjectsState state) {
    if (!state.isLoaded) return const Center(child: CircularProgressIndicator(color: _kAccent));
    if (state.projects.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.movie_creation_outlined, color: _kTextSecondary.withValues(alpha: 0.3), size: 72),
        const SizedBox(height: 16),
        Text('No projects yet', style: GoogleFonts.outfit(color: _kTextSecondary, fontSize: 16)),
        const SizedBox(height: 8),
        Text('Tap + to create one', style: GoogleFonts.outfit(color: _kTextSecondary.withValues(alpha: 0.5), fontSize: 13)),
      ]));
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: state.projects.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (_, i) => _projectCard(state.projects[i]),
    );
  }

  Widget _projectCard(Project project) {
    final isVideo = project.type == 'video';
    final dateStr = '${project.updatedAt.day.toString().padLeft(2, '0')}.${project.updatedAt.month.toString().padLeft(2, '0')}.${project.updatedAt.year}';
    final timeStr = '${project.updatedAt.hour.toString().padLeft(2, '0')}:${project.updatedAt.minute.toString().padLeft(2, '0')}';
    
    return GestureDetector(
      onTap: () async {
        ref.read(projectsProvider.notifier).updateProjectTimestamp(project.id);
        if (isVideo) {
          await ref.read(editorProvider.notifier).loadProject(project.id);
          if (mounted) context.push('/video-editor');
        } else {
          await ref.read(audioEditorProvider.notifier).loadProject(project.id);
          if (mounted) context.push('/audio-editor');
        }
      },
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(48),
          color: const Color(0xFF2A2C22),
        ),
        child: Stack(
          children: [
            // Background Image or Default
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(48),
                child: project.thumbnailPath != null && File(project.thumbnailPath!).existsSync()
                    ? Image.file(
                        File(project.thumbnailPath!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _defaultThumbnail(isVideo),
                      )
                    : _defaultThumbnail(isVideo),
              ),
            ),
            
            // Gradient Overlay for readability
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(48),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.5),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.3),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // Top Left Info Pills
            Positioned(
              left: 20,
              top: 20,
              child: Row(
                children: [
                  _pill(timeStr),
                  const SizedBox(width: 8),
                  _pill(dateStr),
                ],
              ),
            ),
            
            // Edit Button Top Right
            Positioned(
              right: 20,
              top: 20,
              child: GestureDetector(
                onTap: () => _showProjectMenu(project),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: _kAccent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit, color: Colors.black, size: 20),
                ),
              ),
            ),
            
            // Bottom Type Badge (optional, but good for UX)
            Positioned(
              bottom: 20,
              left: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(isVideo ? Icons.videocam_rounded : Icons.audiotrack_rounded, color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Text(project.name, style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _defaultThumbnail(bool isVideo) {
    if (isVideo) {
      return Container(
        color: const Color(0xFF1E1E1E),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_circle_fill_rounded, color: Colors.white54, size: 64),
          ),
        ),
      );
    } else {
      return Container(
        color: const Color(0xFF1E1E1E),
        child: Center(
          child: _AnimatedWaveform(),
        ),
      );
    }
  }
}

// ─── Animated Waveform for Audio Projects ──────────────────────────────────────
class _AnimatedWaveform extends StatefulWidget {
  @override
  State<_AnimatedWaveform> createState() => _AnimatedWaveformState();
}

class _AnimatedWaveformState extends State<_AnimatedWaveform> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(7, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            // Create a staggered wave effect using sine wave
            final double phaseOffset = index * 0.5;
            final double value = math.sin((_controller.value * 2 * math.pi) + phaseOffset);
            final double height = 30 + (30 * value.abs()); // Height varies between 30 and 60
            
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: 12,
              height: height,
              decoration: BoxDecoration(
                color: _kAccent.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: _kAccent.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            );
          },
        );
      }),
    );
  }
}

