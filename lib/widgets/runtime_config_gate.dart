import 'dart:async';

import 'package:flutter/material.dart';

import '../services/runtime_app_config_service.dart';
import '../theme/app_colors.dart';

class RuntimeConfigGate extends StatefulWidget {
  const RuntimeConfigGate({super.key, required this.child});

  final Widget child;

  @override
  State<RuntimeConfigGate> createState() => _RuntimeConfigGateState();
}

class _RuntimeConfigGateState extends State<RuntimeConfigGate> {
  Timer? timer;

  @override
  void initState() {
    super.initState();
    unawaited(RuntimeAppConfigService.load(force: true));
    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(RuntimeAppConfigService.load(force: true));
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RuntimeAppConfig>(
      valueListenable: RuntimeAppConfigService.listenable,
      builder: (context, config, _) {
        if (!config.maintenanceEnabled) return widget.child;
        return Material(
          color: AppColors.navy,
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 92,
                      height: 92,
                      decoration: const BoxDecoration(
                        color: AppColors.lime,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.build_circle_outlined,
                        color: AppColors.navy,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Meet6 bakımda',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      config.maintenanceMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => RuntimeAppConfigService.load(force: true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.lime,
                        foregroundColor: AppColors.navy,
                      ),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text(
                        'Tekrar kontrol et',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
