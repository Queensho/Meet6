import 'package:flutter/material.dart';

import '../../models/profile_draft.dart';
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
  final nameController = TextEditingController();
  final birthDateController = TextEditingController();
  final cityController = TextEditingController();
  final bioController = TextEditingController();
  final promptAnswerController = TextEditingController();

  int step = 1;

  bool get canAdvance {
    if (step == 1) {
      return draft.mainPhotoSelected &&
          nameController.text.trim().length >= 2 &&
          birthDateController.text.isNotEmpty &&
          draft.gender != null;
    }
    if (step == 2) {
      return draft.lookingFor != null &&
          cityController.text.trim().length >= 2 &&
          draft.purpose != null;
    }
    return draft.extraPhotoCount >= 2 &&
        bioController.text.trim().length >= 10 &&
        draft.interests.length >= 3 &&
        promptAnswerController.text.trim().length >= 3;
  }

  @override
  void dispose() {
    nameController.dispose();
    birthDateController.dispose();
    cityController.dispose();
    bioController.dispose();
    promptAnswerController.dispose();
    super.dispose();
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

  void _continue() {
    FocusScope.of(context).unfocus();
    draft.name = nameController.text.trim();
    draft.city = cityController.text.trim();
    draft.bio = bioController.text.trim();
    draft.promptAnswer = promptAnswerController.text.trim();

    if (step < 3) {
      setState(() => step++);
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => HomeScreen(profileName: draft.name),
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
          cityController: cityController,
          distanceKm: draft.distanceKm,
          purpose: draft.purpose,
          onLookingForChanged: (value) =>
              setState(() => draft.lookingFor = value),
          onAgeChanged: (values) => setState(() {
            draft.minAge = values.start;
            draft.maxAge = values.end;
          }),
          onDistanceChanged: (value) =>
              setState(() => draft.distanceKm = value),
          onPurposeChanged: (value) => setState(() => draft.purpose = value),
          onChanged: () => setState(() {}),
        );
      default:
        return ProfileStepThree(
          bioController: bioController,
          promptAnswerController: promptAnswerController,
          extraPhotoCount: draft.extraPhotoCount,
          interests: draft.interests,
          onBioChanged: () => setState(() {}),
          onPromptChanged: () => setState(() {}),
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
