import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_colors.dart';
import '../models/user_data_models.dart';

class HeaderWidget extends StatelessWidget {
  const HeaderWidget({
    super.key,
    required this.user,
    required this.workoutName,
    required this.daySuffix,
    required this.now,
    required this.brandName,
  });

  final UserModel user;
  final String workoutName;
  final String daySuffix;
  final DateTime now;
  final String brandName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser?.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    String displayName = user.name;
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final data =
                          snapshot.data!.data() as Map<String, dynamic>;
                      final remoteDisplayName =
                          (data['displayName'] as String?)?.trim() ?? '';
                      final remoteUsername =
                          (data['username'] as String?)?.trim() ?? '';
                      displayName = remoteDisplayName.isNotEmpty
                          ? remoteDisplayName
                          : remoteUsername.isNotEmpty
                          ? remoteUsername
                          : displayName;
                    }

                    final hour = now.hour;
                    String greeting = 'Good Evening';
                    if (hour >= 5 && hour < 12) {
                      greeting = 'Good Morning';
                    } else if (hour >= 12 && hour < 17) {
                      greeting = 'Good Afternoon';
                    }

                    return Text(
                      '$greeting, $displayName',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  '$workoutName $daySuffix',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF888888),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('EEEE, d MMMM y').format(now),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF888888),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.bolt_rounded,
                    color: AppColors.accentPrimary,
                    size: 30,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    brandName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                width: 22,
                height: 3,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.accentPrimary,
                      AppColors.accentSecondary,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
