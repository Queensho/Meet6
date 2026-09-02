import 'package:flutter/material.dart';

import '../../models/profile_draft.dart';
import '../../services/location_service.dart';
import '../../services/session_service.dart';
import '../../widgets/phone_frame.dart';
import '../../widgets/primary_button.dart';
import '../home/home_screen.dart';
import 'profile_step_1.dart';
import 'profile_step_2.dart';
import 'profile_step_3.dart';
import 'widgets/profile_step_header.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final draft = ProfileDraft();
  final locationService = const LocationService();
  final nameController = TextEditingController();
  final birthDateController = TextEditingController();
  final bioController = TextEditingController();
  final promptAnswerController = TextEditingController();

  int step = 1;
  bool locationLoading = false;
  String? locationError;

  bool get canAdvance {
    if (step == 1) {
      return draft.mainPhotoSelected &&
          nameController.text.trim().length >= 2 &&
          birthDateController.text.isNotEmpty &&
          draft.gender != null;
    }
    if (step == 2) {
      return draft.lookingFor != null &&
          draft.hasLocation &&
          draft.purpose != null;
    }
    return draft.extraPhotoCount >= 2 &&
        bioController.text.trim().length >= 3 &&
        draft.interests.isNotEmpty &&
        draft.prompt.trim().isNotEmpty &&
        promptAnswerController.text.trim().length >= 3;
  }

  @override
  void dispose() {
    nameController.dispose();
    birthDateController.dispose();
    bioController.dispose();
    promptAnswerController.dispose();
    super.dispose();
  }

  Future<void> _requestLocation() async {
    if (locationLoading) return;
    setState(() {
      locationLoading = true;
      locationError = null;
    });

    try {
      final location = await locationService.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        draft.latitude = location.latitude;
        draft.longitude = location.longitude;
        draft.city = location.city;
        draft.country = location.country;
        locationLoading = false;
      });
    } on LocationServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        locationLoading = false;
        locationError = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        locationLoading = false;
        locationError = 'Konum alınamadı. İzinlerini kontrol edip tekrar dene.';
      });
    }
  }

  Future<void> _pickBirthDate() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final latest = DateTime(now.year - 18, now.month, now.day);
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(latest.year - 7, latest.month, latest.day),
      firstDate: DateTime(1940),
      lastDate: latest,
      helpText: 'Doğum tarihini seç',
      cancelText: 'İptal',
      confirmText: 'Seç',
    );
    if (date == null || !mounted) return;
    final formatted =
        '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    birthDateController.text = formatted;
    draft.birthDate = formatted;
    setState(() {});
  }

  void _goBack() {
    FocusScope.of(context).unfocus();
    if (step > 1) {
      setState(() => step--);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _continue() async {
    FocusScope.of(context).unfocus();
    draft.name = nameController.text.trim();
    draft.bio = bioController.text.trim();
    draft.promptAnswer = promptAnswerController.text.trim();

    if (step == 1) {
      setState(() => step = 2);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !draft.hasLocation) _requestLocation();
      });
      return;
    }

    if (step == 2) {
      setState(() => step = 3);
      return;
    }

    final lookingFor = draft.lookingFor ?? 'Herkes';
    final purpose = draft.purpose ?? 'Yeni insanlarla tanışma';

    await SessionService.saveProfile(
      profileName: draft.name,
      city: draft.city,
      country: draft.country,
      latitude: draft.latitude,
      longitude: draft.longitude,
      distanceKm: draft.distanceKm,
      lookingFor: lookingFor,
      minAge: draft.minAge,
      maxAge: draft.maxAge,
      purpose: purpose,
    );

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          profileName: draft.name,
          city: draft.city,
          country: draft.country,
          latitude: draft.latitude,
          longitude: draft.longitude,
          distanceKm: draft.distanceKm,
          lookingFor: lookingFor,
          minAge: draft.minAge,
          maxAge: draft.maxAge,
          purpose: purpose,
        ),
      ),
      (route) => false,
    );
  }

  void _toggleInterest(String value) {
    setState(() {
      if (draft.interests.contains(value)) {
        draft.interests.remove(value);
      } else if (draft.interests.length < 5) {
        draft.interests.add(value);
      }
    });
  }

  Widget _currentStep() {
    switch (step) {
      case 1:
        return ProfileStepOne(
          nameController: nameController,
          birthDateController: birthDateController,
          gender: draft.gender,
          photoSelected: draft.mainPhotoSelected,
          onChanged: () => setState(() {}),
          onPickBirthDate: _pickBirthDate,
          onGenderChanged: (value) => setState(() => draft.gender = value),
          onPhotoToggle: () => setState(
            () => draft.mainPhotoSelected = !draft.mainPhotoSelected,
          ),
        );
      case 2:
        return ProfileStepTwo(
          lookingFor: draft.lookingFor,
          minAge: draft.minAge,
          maxAge: draft.maxAge,
          locationLabel: draft.locationLabel,
          locationLoading: locationLoading,
          locationError: locationError,
          distanceKm: draft.distanceKm,
          purpose: draft.purpose,
          onLookingForChanged: (value) =>
              setState(() => draft.lookingFor = value),
          onAgeChanged: (values) => setState(() {
            draft.minAge = values.start;
            draft.maxAge = values.end;
          }),
          onRequestLocation: _requestLocation,
          onDistanceChanged: (value) =>
              setState(() => draft.distanceKm = value),
          onPurposeChanged: (value) => setState(() => draft.purpose = value),
        );
      default:
        return ProfileStepThree(
          bioController: bioController,
          promptAnswerController: promptAnswerController,
          extraPhotoCount: draft.extraPhotoCount,
          interests: draft.interests,
          selectedPrompt: draft.prompt,
          onBioChanged: () => setState(() {}),
          onPromptChanged: () => setState(() {}),
          onPromptSelected: (value) => setState(() {
            draft.prompt = value;
            promptAnswerController.clear();
          }),
          onExtraPhotoCountChanged: (value) =>
              setState(() => draft.extraPhotoCount = value),
          onInterestToggle: _toggleInterest,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: PhoneFrame(
        child: LayoutBuilder(
          builder: (context, phone) {
            final h = phone.maxHeight;
            final horizontal = (phone.maxWidth * .055).clamp(18.0, 24.0);

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 12),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (h - 24).clamp(0.0, double.infinity),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProfileStepHeader(step: step, onBack: _goBack),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: KeyedSubtree(
                        key: ValueKey(step),
                        child: _currentStep(),
                      ),
                    ),
                    const SizedBox(height: 26),
                    PrimaryButton(
                      label: step == 3 ? 'Profili tamamla' : 'Devam et',
                      onPressed: canAdvance ? _continue : null,
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
