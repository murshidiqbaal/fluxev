import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/neon_button.dart';

class ReviewsScreen extends ConsumerStatefulWidget {
  final String stationId;

  const ReviewsScreen({super.key, required this.stationId});

  @override
  ConsumerState<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends ConsumerState<ReviewsScreen> {
  final _commentCtrl = TextEditingController();
  int _userRating = 0;
  bool _submitting = false;
  List<Map<String, dynamic>> _reviews = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    final data = await Supabase.instance.client
        .from('reviews')
        .select('*, user:users(full_name)')
        .eq('station_id', widget.stationId)
        .order('created_at', ascending: false);
    setState(() {
      _reviews = List<Map<String, dynamic>>.from(data);
      _loading = false;
    });
  }

  Future<void> _submitReview() async {
    if (_userRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a star rating')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');
      await Supabase.instance.client.from('reviews').insert({
        'user_id': userId,
        'station_id': widget.stationId,
        'rating': _userRating,
        'comment': _commentCtrl.text.trim(),
      });
      _commentCtrl.clear();
      setState(() => _userRating = 0);
      await _loadReviews();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.error),
      );
    }
    setState(() => _submitting = false);
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Station Reviews'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Submit review
          Padding(
            padding: const EdgeInsets.all(16),
            child: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Leave a Review',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 12),
                  // Star selector
                  Row(
                    children: List.generate(
                      5,
                      (i) => GestureDetector(
                        onTap: () => setState(() => _userRating = i + 1),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(
                            i < _userRating
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: i < _userRating
                                ? AppColors.warning
                                : AppColors.textSecondary,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _commentCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'Write your experience...',
                    ),
                  ),
                  const SizedBox(height: 14),
                  NeonButton(
                    label: 'Post Review',
                    isLoading: _submitting,
                    onPressed: _submitReview,
                    icon: Icons.rate_review_outlined,
                  ),
                ],
              ),
            ).animate().fadeIn(),
          ),
          // Reviews list
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _reviews.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.rate_review_outlined,
                                color: AppColors.textSecondary, size: 52),
                            const SizedBox(height: 12),
                            const Text('No reviews yet. Be the first!',
                                style:
                                    TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _reviews.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final r = _reviews[i];
                          final rating = r['rating'] as int;
                          final name = (r['users']?['full_name'] as String?) ??
                              'Anonymous';
                          return GlassCard(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor:
                                          AppColors.primary.withOpacity(0.2),
                                      child: Text(
                                        name[0].toUpperCase(),
                                        style: const TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
                                    const Spacer(),
                                    Row(
                                      children: List.generate(
                                        5,
                                        (j) => Icon(
                                          j < rating
                                              ? Icons.star_rounded
                                              : Icons.star_border_rounded,
                                          color: AppColors.warning,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (r['comment'] != null &&
                                    (r['comment'] as String).isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(r['comment'] as String,
                                      style: const TextStyle(
                                          color: AppColors.textSecondary)),
                                ],
                              ],
                            ),
                          ).animate(delay: (i * 60).ms).fadeIn();
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
