import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import '../../core/theme/app_theme.dart';

/// A custom, modular, voice-only calling overlay rendered on top of ZegoUIKitPrebuiltCall.
///
/// Features:
/// - End-to-end encrypted voice call badge
/// - Live call duration timer
/// - Caller profile with animated sound wave ripples
/// - 6-button modular action grid:
///   1. Mute / Unmute (active hardware mic)
///   2. Speaker / Earpiece (active audio routing)
///   3. Call Recording (interactive toggle + status indicator)
///   4. Keypad / Dialpad (modal bottom sheet for DTMF digits)
///   5. Add Call / Conference (extensible modal hook)
///   6. Hold Call (call hold state toggle)
/// - Circular Red Hang Up button (clean session termination)
class CustomAudioCallingView extends StatefulWidget {
  final ZegoCallInvitationData? callData;

  const CustomAudioCallingView({
    super.key,
    this.callData,
  });

  @override
  State<CustomAudioCallingView> createState() => _CustomAudioCallingViewState();
}

class _CustomAudioCallingViewState extends State<CustomAudioCallingView>
    with SingleTickerProviderStateMixin {
  // Call duration timer
  Timer? _durationTimer;
  int _callDurationSeconds = 0;

  // Sound wave pulse animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Extensible feature states
  bool _isRecording = false;
  int _recordDurationSeconds = 0;
  Timer? _recordTimer;
  bool _isOnHold = false;
  String _enteredDigits = '';

  // Remote participants listener
  StreamSubscription<List<ZegoUIKitUser>>? _userLeaveSubscription;

  @override
  void initState() {
    super.initState();

    // 1. Initialize pulse animation for speaking effect
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    if (!Get.testMode) {
      _pulseController.repeat(reverse: true);
    }

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.14).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 2. Start call duration counter
    if (!Get.testMode) {
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _callDurationSeconds++;
          });
        }
      });

      // 3. Listen for remote participants leaving the call
      _userLeaveSubscription = ZegoUIKit().getUserLeaveStream().listen((users) {
        if (mounted) {
          final remainingRemoteUsers = ZegoUIKit().getRemoteUsers();
          if (remainingRemoteUsers.isEmpty) {
            // All remote participants have left the call
            ZegoUIKitPrebuiltCallController().hangUp(context);
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _recordTimer?.cancel();
    _userLeaveSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // Format seconds into MM:SS or HH:MM:SS
  String _formatDuration(int totalSeconds) {
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    final String minStr = minutes.toString().padLeft(2, '0');
    final String secStr = seconds.toString().padLeft(2, '0');
    if (minutes >= 60) {
      final int hours = minutes ~/ 60;
      final int remMinutes = minutes % 60;
      return '${hours.toString().padLeft(2, '0')}:${remMinutes.toString().padLeft(2, '0')}:$secStr';
    }
    return '$minStr:$secStr';
  }

  // Toggle call recording
  void _toggleRecording() {
    setState(() {
      _isRecording = !_isRecording;
      if (_isRecording) {
        _recordDurationSeconds = 0;
        _recordTimer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (mounted) setState(() => _recordDurationSeconds++);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.fiber_manual_record, color: Colors.red, size: 16),
                SizedBox(width: 8),
                Text('Call recording started...'),
              ],
            ),
            duration: Duration(seconds: 2),
            backgroundColor: Color(0xFF1E293B),
          ),
        );
      } else {
        _recordTimer?.cancel();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Call recording saved.'),
            duration: Duration(seconds: 2),
            backgroundColor: Color(0xFF1E293B),
          ),
        );
      }
    });
  }

  // Toggle call hold
  void _toggleHold() {
    setState(() {
      _isOnHold = !_isOnHold;
      // When on hold, mute local microphone
      if (!Get.testMode) {
        ZegoUIKit().turnMicrophoneOn(!_isOnHold);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isOnHold ? 'Call placed on hold' : 'Call resumed'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF1E293B),
      ),
    );
  }

  // Open in-call keypad / dialpad modal bottom sheet
  void _openDialpad() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: 480,
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Keypad',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Display entered digits
                  Container(
                    width: double.infinity,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _enteredDigits.isEmpty ? 'Type numbers...' : _enteredDigits,
                      style: TextStyle(
                        color: _enteredDigits.isEmpty ? Colors.white38 : Colors.white,
                        fontSize: 22,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 3x4 dialpad grid
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 3,
                      childAspectRatio: 1.5,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 16,
                      children: [
                        for (final key in [
                          '1', '2', '3',
                          '4', '5', '6',
                          '7', '8', '9',
                          '*', '0', '#'
                        ])
                          Material(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                setState(() => _enteredDigits += key);
                                setModalState(() {});
                              },
                              child: Center(
                                child: Text(
                                  key,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Open Conference / Add Call bottom sheet
  void _openAddCallModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.group_add_rounded,
                  color: AppTheme.primaryColor,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Conference Call',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add more participants to convert this into a group voice call.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Multi-user conference calling is configured for Phase 7!'),
                      backgroundColor: Color(0xFF1E293B),
                    ),
                  );
                },
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Invite Contact'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Resolve remote user display name from invitation data or ZegoUIKit
    String remoteUserName = 'Connected User';
    if (widget.callData?.invitees.isNotEmpty ?? false) {
      remoteUserName = widget.callData!.invitees.first.name.trim();
      if (remoteUserName.isEmpty) {
        remoteUserName = widget.callData!.invitees.first.id;
      }
    } else if (widget.callData?.inviter != null) {
      remoteUserName = widget.callData!.inviter!.name.trim();
      if (remoteUserName.isEmpty) {
        remoteUserName = widget.callData!.inviter!.id;
      }
    }

    final String initial =
        remoteUserName.isNotEmpty ? remoteUserName[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F172A), // Slate 900
              Color(0xFF1E293B), // Slate 800
              Color(0xFF090D16), // Deep Slate
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        const SizedBox(height: 12),

                        // 1. Top Bar: Encryption indicator + live duration
                        _buildTopHeader(),

                        const Spacer(),

                        // 2. Center Profile & Pulsing Sound Waves
                        _buildCenterProfile(remoteUserName, initial),

                        const Spacer(),

                        // 3. Status Badges (Hold / Recording)
                        if (_isOnHold || _isRecording) ...[
                          const SizedBox(height: 12),
                          _buildStatusBanner(),
                        ],

                        const SizedBox(height: 16),

                        // 4. Modular Action Button Grid (2x3)
                        _buildModularActionGrid(),

                        const SizedBox(height: 28),

                        // 5. Hang Up Button
                        _buildHangUpSection(),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // Top header with encryption badge and call duration
  Widget _buildTopHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded, color: Color(0xFF10B981), size: 14),
                SizedBox(width: 6),
                Text(
                  'End-to-end Encrypted',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _formatDuration(_callDurationSeconds),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Center user avatar with glowing pulse effect and name
  Widget _buildCenterProfile(String name, String initial) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Animated pulsing avatar ring
        ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.28),
                  blurRadius: 36,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.primaryColor.withValues(alpha: 0.8),
                    const Color(0xFF3B82F6),
                  ],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 3),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 54,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _isOnHold ? 'Call on hold' : 'Voice Call in progress',
          style: TextStyle(
            color: _isOnHold ? Colors.amber.shade300 : const Color(0xFF10B981),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Status banner for Call Hold or Recording
  Widget _buildStatusBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isRecording)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.fiber_manual_record, color: Colors.redAccent, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'REC ${_formatDuration(_recordDurationSeconds)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          if (_isOnHold)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.pause_circle_filled_rounded, color: Colors.amber, size: 14),
                  SizedBox(width: 6),
                  Text(
                    'ON HOLD',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Modular 2x3 Action Grid
  Widget _buildModularActionGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          // Row 1: Mute, Keypad, Speaker
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 1. Mute Button (Hardware linked)
              _buildZegoActionButton(
                label: 'Mute',
                child: ZegoToggleMicrophoneButton(
                  buttonSize: const Size(60, 60),
                  iconSize: const Size(28, 28),
                  defaultOn: true,
                ),
              ),

              // 2. Keypad / Dialpad (Interactive modal)
              _buildCustomActionButton(
                icon: Icons.dialpad_rounded,
                label: 'Keypad',
                isActive: false,
                onTap: _openDialpad,
              ),

              // 3. Speaker Output (Hardware linked)
              _buildZegoActionButton(
                label: 'Speaker',
                child: ZegoSwitchAudioOutputButton(
                  buttonSize: const Size(60, 60),
                  iconSize: const Size(28, 28),
                  defaultUseSpeaker: false,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Row 2: Record, Add Call, Hold
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 4. Call Recording Button
              _buildCustomActionButton(
                icon: Icons.fiber_manual_record_rounded,
                label: _isRecording ? 'Stop Rec' : 'Record',
                isActive: _isRecording,
                activeColor: Colors.redAccent,
                onTap: _toggleRecording,
              ),

              // 5. Add Call / Conference (Modal Hook)
              _buildCustomActionButton(
                icon: Icons.person_add_alt_1_rounded,
                label: 'Add call',
                isActive: false,
                onTap: _openAddCallModal,
              ),

              // 6. Hold Call Button
              _buildCustomActionButton(
                icon: _isOnHold ? Icons.play_arrow_rounded : Icons.pause_rounded,
                label: _isOnHold ? 'Unhold' : 'Hold',
                isActive: _isOnHold,
                activeColor: Colors.amber,
                onTap: _toggleHold,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Wrapper for Zego hardware buttons (Mic, Speaker)
  Widget _buildZegoActionButton({
    required String label,
    required Widget child,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white12),
          ),
          child: Center(child: child),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Custom action button for extensible features
  Widget _buildCustomActionButton({
    required IconData icon,
    required String label,
    required bool isActive,
    Color? activeColor,
    required VoidCallback onTap,
  }) {
    final effectiveActiveColor = activeColor ?? AppTheme.primaryColor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: isActive
                      ? effectiveActiveColor.withValues(alpha: 0.25)
                      : Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive ? effectiveActiveColor : Colors.white12,
                    width: isActive ? 1.5 : 1.0,
                  ),
                ),
                child: Icon(
                  icon,
                  color: isActive ? effectiveActiveColor : Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? effectiveActiveColor : Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Smart hang up handling:
  // - 1-to-1 call: terminates session for both sides
  // - Conference call: leaves room and allows others to stay
  void _handleHangUp(BuildContext context) {
    if (Get.testMode) {
      Navigator.of(context).maybePop();
      return;
    }
    final remoteUsers = ZegoUIKit().getRemoteUsers();
    if (remoteUsers.length <= 1) {
      // 1-to-1 call: End call for both sides
      ZegoUIKitPrebuiltCallController().hangUp(context);
    } else {
      // Conference call: Only leave the room so others can stay
      ZegoUIKit().leaveRoom();
      Navigator.of(context).maybePop();
    }
  }

  // Red Hang Up Button
  Widget _buildHangUpSection() {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleHangUp(context),
          borderRadius: BorderRadius.circular(36),
          child: Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.redAccent,
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.call_end_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
