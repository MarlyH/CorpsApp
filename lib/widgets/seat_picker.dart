import 'package:corpsapp/models/event_detail.dart';
import 'package:corpsapp/theme/colors.dart';
import 'package:flutter/material.dart';

class SeatPickerSheet extends StatefulWidget {
  final Future<EventDetail> futureDetail;
  final int? initialSelected;
  final int eventTotalSeats; // from EventSummary (non-nullable)
  final ValueChanged<int> onSeatPicked;
  final bool isReserveFlow;

  const SeatPickerSheet({
    super.key,
    required this.futureDetail,
    required this.initialSelected,
    required this.eventTotalSeats,
    required this.onSeatPicked,
    this.isReserveFlow = false
  });

  @override
  State<SeatPickerSheet> createState() => _SeatPickerSheetState();
}

class _SeatPickerSheetState extends State<SeatPickerSheet> {
  int? _picked;

  @override
  void initState() {
    super.initState();
    _picked = widget.initialSelected;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Header     
            if (!widget.isReserveFlow) ... [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Select a Ticket Number',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),                             
                ],
              ),    

              const SizedBox(height: 4),  

              Text(
                'Select a lucky number to represent your ticket for this event. This number does not represent a physical seat.',
                style: TextStyle(
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),   
            ], 

            const SizedBox(height: 16),
                                                                  
            // Content
            Expanded(
              child: FutureBuilder<EventDetail>(
                future: widget.futureDetail,
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }
                  if (snap.hasError || snap.data == null) {
                    return const Center(
                      child: Text('Error loading Tickets',
                          style: TextStyle(color: AppColors.errorColor)),
                    );
                  }

                  final detail = snap.data!;
                  final availableSeats = detail.availableSeats.toSet();

                  // Determine total seats:
                  // Prefer EventDetail.totalSeats (if present) → EventSummary.totalSeats (passed in) → highest available seat number
                  int totalSeats = 0;
                  final int? detailTotal = detail.totalSeats; 
                  if (detailTotal != null && detailTotal > 0) {
                    totalSeats = detailTotal;
                  } else if (widget.eventTotalSeats > 0) {
                    totalSeats = widget.eventTotalSeats;
                  } else {
                    totalSeats = availableSeats.isNotEmpty
                        ? availableSeats.reduce((a, b) => a > b ? a : b)
                        : 0;
                  }

                  //this should never happen
                  if (totalSeats <= 0) {
                    return const Center(
                      child: Text('No tickets available',
                          style: TextStyle(color: Colors.white70)),
                    );
                  }

                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Legend
                        Row(
                          children: const [
                            _LegendSwatch(color: Colors.white, border: Colors.white24),
                            SizedBox(width: 4),
                            Text('Available', style: TextStyle(color: Colors.white70)),
                            SizedBox(width: 16),
                            _LegendSwatch(color: Color(0xFF67788E), border: Colors.white24),
                            SizedBox(width: 4),
                            Text('Taken', style: TextStyle(color: Colors.white70)),
                            SizedBox(width: 16),
                            _LegendSwatch(color: Color(0xFF4C85D0), border: Colors.transparent),
                            SizedBox(width: 4),
                            Text('Selected', style: TextStyle(color: Colors.white70)),
                          ],
                        ),
                        
                        const SizedBox(height: 16),

                        // Grid (scrolls independently)
                        Expanded(
                          child: GridView.builder(
                            padding: EdgeInsets.zero,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 1.2,
                            ),

                            itemCount: totalSeats,
                            itemBuilder: (_, idx) {
                              final seat = idx + 1;
                              final available = availableSeats.contains(seat);
                              final selected = _picked == seat;

                              return _SeatTile(
                                seat: seat,
                                available: available,
                                selected: selected,
                                onTap: available
                                    ? () {
                                        setState(() => _picked = seat);
                                        widget.onSeatPicked(seat); 
                                      }
                                    : null,
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 16),                                          
                      ],
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

// widgets used inside the sheet for the seat tiles and legend
class _SeatTile extends StatelessWidget {
  final int seat;
  final bool available;
  final bool selected;
  final VoidCallback? onTap;

  const _SeatTile({
    required this.seat,
    required this.available,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = !available
        ? const Color(0xFF67788E)
        : (selected ? const Color(0xFF4C85D0) : Colors.white);
    final fg = !available
        ? const Color.fromARGB(255, 255, 255, 255)
        : (selected ? Colors.white : Colors.black87);
    final border = selected ? const Color(0xFF4C85D0) : Colors.white24;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border, width: selected ? 2 : 1),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!available) const SizedBox(width: 6),
              Text(
                seat.toString(),
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendSwatch extends StatelessWidget {
  final Color color;
  final Color border;
  const _LegendSwatch({required this.color, required this.border});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border, width: 1),
      ),
    );
  }
}