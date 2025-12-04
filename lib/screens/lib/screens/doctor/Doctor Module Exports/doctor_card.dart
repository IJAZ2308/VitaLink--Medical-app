import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../models/doctor.dart';

class DoctorCard extends StatefulWidget {
  final Doctor doctor;
  final VoidCallback? onTap;

  const DoctorCard({
    super.key,
    required this.doctor,
    this.onTap,
    required void Function() onBookPressed,
  });

  @override
  State<DoctorCard> createState() => _DoctorCardState();
}

class _DoctorCardState extends State<DoctorCard> {
  late double averageRating;
  late int numberOfReviews;
  late double totalReviews;

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child(
    'users',
  );

  @override
  void initState() {
    super.initState();
    totalReviews = widget.doctor.totalReviews.toDouble();
    numberOfReviews = widget.doctor.numberOfReviews;
    averageRating = numberOfReviews > 0 ? totalReviews / numberOfReviews : 0;
  }

  Future<void> _writeReview(BuildContext context) async {
    final TextEditingController ratingController = TextEditingController();
    final TextEditingController reviewController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Write a Review"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ratingController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Rating (1-5)"),
              ),
              TextField(
                controller: reviewController,
                decoration: const InputDecoration(labelText: "Review Comment"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final double rating =
                    double.tryParse(ratingController.text) ?? 0;
                if (rating <= 0 || rating > 5) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Enter a valid rating between 1-5"),
                    ),
                  );
                  return;
                }

                final doctorRef = _dbRef.child(widget.doctor.uid);

                // Update Firebase Realtime Database
                await doctorRef.runTransaction(
                  (mutableData) async {
                        final data =
                            mutableData?.value as Map<dynamic, dynamic>? ?? {};

                        double currentTotal = (data['totalReviews'] ?? 0)
                            .toDouble();
                        int currentCount = (data['numberOfReviews'] ?? 0);

                        currentTotal += rating;
                        currentCount += 1;

                        List<dynamic> reviews = List.from(
                          data['reviews'] ?? [],
                        );
                        if (reviewController.text.isNotEmpty) {
                          reviews.add(reviewController.text);
                        }

                        mutableData!.value = {
                          ...data,
                          'totalReviews': currentTotal,
                          'numberOfReviews': currentCount,
                          'reviews': reviews,
                        };
                        return mutableData;
                      }
                      as TransactionHandler,
                );

                setState(() {
                  totalReviews += rating;
                  numberOfReviews += 1;
                  averageRating = totalReviews / numberOfReviews;
                });

                // ignore: use_build_context_synchronously
                Navigator.of(ctx).pop();
                // ignore: use_build_context_synchronously
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Review submitted!")),
                );
              },
              child: const Text("Submit"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: widget.doctor.profileImageUrl.isNotEmpty
                        ? NetworkImage(widget.doctor.profileImageUrl)
                        : const AssetImage('assets/images/default_doctor.png')
                              as ImageProvider,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.doctor.fullName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${widget.doctor.category} • ${widget.doctor.workingAt}",
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.doctor.city,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "${averageRating.toStringAsFixed(1)} ($numberOfReviews reviews)",
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (widget.doctor.specialization.isNotEmpty)
                          Wrap(
                            spacing: 6,
                            runSpacing: -4,
                            children: widget.doctor.specialization
                                .map(
                                  (spec) => Chip(
                                    label: Text(
                                      spec,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                    backgroundColor: Colors.blueAccent,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                ],
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => _writeReview(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text("Write Review"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
