import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zego_uikit/zego_uikit.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../services/zego_call_service.dart';
import '../contacts/contacts_controller.dart';

/// Interactive modal sheet to invite a registered contact into an active audio/video conference
class InviteParticipantSheet extends StatefulWidget {
  final bool isVideo;

  const InviteParticipantSheet({
    super.key,
    required this.isVideo,
  });

  static Future<void> show(BuildContext context, {required bool isVideo}) {
    return showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => InviteParticipantSheet(isVideo: isVideo),
    );
  }

  @override
  State<InviteParticipantSheet> createState() => _InviteParticipantSheetState();
}

class _InviteParticipantSheetState extends State<InviteParticipantSheet> {
  final UserService _userService = UserService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  List<UserModel> _allContacts = [];
  List<UserModel> _filteredContacts = [];
  Set<String> _connectedUserIds = <String>{};
  bool _isLoading = true;
  String _invitingUserId = '';

  @override
  void initState() {
    super.initState();
    final myUid = _authService.currentUserId;
    if (myUid != null && myUid.isNotEmpty) {
      _connectedUserIds.add(myUid);
    }

    if (!Get.testMode) {
      try {
        final remote = ZegoUIKit().getRemoteUsers();
        for (final u in remote) {
          _connectedUserIds.add(u.id);
        }
      } catch (e) {
        debugPrint('Pre-seed remote users: $e');
      }
    }

    // Fast-path: prefill with cached contacts from ContactsController if present
    if (Get.isRegistered<ContactsController>()) {
      try {
        final cached = Get.find<ContactsController>().users;
        if (cached.isNotEmpty) {
          final others = myUid != null && myUid.isNotEmpty
              ? cached.where((u) => u.uid != myUid).toList()
              : List<UserModel>.from(cached);
          _allContacts = others;
          _filteredContacts = others;
          _isLoading = false;
        }
      } catch (e) {
        debugPrint('Cache check: $e');
      }
    }

    _fetchAvailableContacts();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAvailableContacts() async {
    if (_allContacts.isEmpty) {
      setState(() => _isLoading = true);
    }

    try {
      final all = await _userService.getUsers();
      final currentUid = _authService.currentUserId;

      final connectedIds = <String>{};
      if (currentUid != null && currentUid.isNotEmpty) {
        connectedIds.add(currentUid);
      }

      if (!Get.testMode) {
        try {
          final remote = ZegoUIKit().getRemoteUsers();
          for (final u in remote) {
            connectedIds.add(u.id);
          }
        } catch (e) {
          debugPrint('Error getting remote users: $e');
        }
      }

      // Filter out only the current user so existing participants stay visible with "In Call" badge
      final others = currentUid != null && currentUid.isNotEmpty
          ? all.where((u) => u.uid != currentUid).toList()
          : all;

      if (mounted) {
        setState(() {
          _connectedUserIds = connectedIds;
          _allContacts = others;
          _onSearchChanged();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading contacts for conference: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      _filteredContacts = List.from(_allContacts);
    } else {
      _filteredContacts = _allContacts.where((u) {
        final name = u.name.toLowerCase();
        final email = u.email.toLowerCase();
        return name.contains(query) || email.contains(query);
      }).toList();
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _inviteContact(UserModel user) async {
    setState(() => _invitingUserId = user.uid);

    final success = await ZegoCallService.instance.inviteToOngoingCall(
      targetUser: user,
      isVideo: widget.isVideo,
    );

    if (mounted) {
      setState(() => _invitingUserId = '');
      if (success) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.isVideo ? Icons.video_call_rounded : Icons.add_call,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isVideo ? 'Add to Video Conference' : 'Add to Voice Conference',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Invite contact to join ongoing call',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search bar
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search contacts...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.white60),
              filled: true,
              fillColor: Colors.black26,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Contacts List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primaryColor),
                  )
                : _filteredContacts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_off_rounded, size: 48, color: Colors.white.withValues(alpha: 0.35)),
                            const SizedBox(height: 12),
                            Text(
                              _allContacts.isEmpty
                                  ? 'No other registered contacts found'
                                  : 'No contacts match your search',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _filteredContacts.length,
                        separatorBuilder: (context, index) => const Divider(color: Colors.white12, height: 1),
                        itemBuilder: (context, index) {
                          final user = _filteredContacts[index];
                          final isAlreadyInCall = _connectedUserIds.contains(user.uid);
                          final isInviting = _invitingUserId == user.uid;

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            leading: CircleAvatar(
                              radius: 22,
                              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                              backgroundImage: user.profileImage.isNotEmpty
                                  ? NetworkImage(user.profileImage)
                                  : null,
                              child: user.profileImage.isEmpty
                                  ? Text(
                                      user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    )
                                  : null,
                            ),
                            title: Text(
                              user.name.isNotEmpty ? user.name : 'User',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: Text(
                              user.email,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                              ),
                            ),
                            trailing: isAlreadyInCall
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white12),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.phone_in_talk_rounded, color: Colors.greenAccent, size: 14),
                                        SizedBox(width: 6),
                                        Text(
                                          'In Call',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ElevatedButton.icon(
                                    onPressed: isInviting ? null : () => _inviteContact(user),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: isInviting
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.add_rounded, size: 18),
                                    label: Text(
                                      isInviting ? 'Inviting' : 'Invite',
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                  ),
                          );
                        },
                      ),
          ),
        ],
      ),
    ),
    );
  }
}
