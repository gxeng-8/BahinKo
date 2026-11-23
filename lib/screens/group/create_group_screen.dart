/// Figma Frame 4 "Create Group" (New Group): pick a template, name the
/// group, choose a category, and pick members.
///
/// COURSE REQUIREMENT (c): form with input validation and clear error
/// feedback. Every input lives inside one [Form], including the member
/// picker (a custom [FormField]), so a single `validate()` call checks all.
library;

import 'package:flutter/material.dart';

import 'package:bahinko/data/mock_data.dart';
import 'package:bahinko/models/group.dart';
import 'package:bahinko/models/person.dart';
import 'package:bahinko/screens/group/group_detail_screen.dart';
import 'package:bahinko/screens/group/widgets/add_member_dialog.dart';
import 'package:bahinko/services/group_service.dart';
import 'package:bahinko/theme/app_colors.dart';
import 'package:bahinko/theme/app_theme.dart';
import 'package:bahinko/widgets/app_page.dart';
import 'package:bahinko/widgets/app_toast.dart';
import 'package:bahinko/widgets/avatar.dart';
import 'package:bahinko/widgets/btn.dart';

/// The four template cards and the category each one pre-selects.
const _templates = [
  (title: 'Trip', subtitle: 'Transport, Food, Lodging', category: 'Trips'),
  (
    title: 'Household',
    subtitle: 'Rent, WiFi, Electricity',
    category: 'Boarding',
  ),
  (
    title: 'Dinner or Event',
    subtitle: 'Food, Drinks, Service',
    category: 'Dinner',
  ),
  (title: 'Custom', subtitle: 'Start from scratch', category: 'Custom'),
];

class CreateGroup extends StatefulWidget {
  const CreateGroup({super.key, this.initialCategory});

  /// Pre-selected category when opened from the Home category grid.
  final GroupCategory? initialCategory;

  @override
  State<CreateGroup> createState() => _CreateGroupState();
}

class _CreateGroupState extends State<CreateGroup> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  late GroupCategory _category;

  /// Friends you can add with one tap (everyone except "You").
  final List<Person> _friends = people.where((p) => p != you).toList();

  /// Members picked so far. "You" is always in the group.
  final List<Person> _selected = [you];

  /// True while the group is being saved (disables the button).
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory ?? categoryNamed('Trips');
  }

  @override
  void dispose() {
    _nameController.dispose(); // controllers must be disposed to free memory
    super.dispose();
  }

  // ---------- Validators (return null = valid, or an error message) ----------

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Give your group a name';
    if (name.length < 3) return 'Name must be at least 3 characters';
    if (name.length > 40) return 'Keep the name under 40 characters';
    return null;
  }

  String? _validateMembers(List<Person>? members) =>
      (members?.length ?? 0) < 2 ? 'Add at least one other member' : null;

  // ---------- Actions ----------

  /// Tapping a template card selects its category.
  void _pickTemplate(String categoryName) =>
      setState(() => _category = categoryNamed(categoryName));

  /// Adds/removes a friend. "You" can't be removed.
  void _toggleMember(Person person, FormFieldState<List<Person>> field) {
    if (person == you) return;
    setState(() {
      _selected.contains(person)
          ? _selected.remove(person)
          : _selected.add(person);
    });
    field.didChange(_selected); // re-runs the validator so the error clears
  }

  /// "+" button: type a new person's name (reuses the Members dialog).
  Future<void> _addNewPerson(FormFieldState<List<Person>> field) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AddMemberDialog(
        onAdd: (name) => setState(() {
          final person = personFromName(
            name,
            colorIndex: _friends.length + 1,
            // Unique ID: expense shares are stored per member ID.
            id: 'guest-${DateTime.now().microsecondsSinceEpoch}',
          );
          _friends.add(person);
          _selected.add(person);
        }),
      ),
    );
    field.didChange(_selected);
  }

  /// Validates the whole form; if OK, saves the group and opens it.
  /// Validates the whole form; if OK, saves the group and opens it.
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return; // errors show inline

    setState(() => _saving = true); // loading state on the button
    try {
      final group = await GroupService.instance.createGroup(
        name: _nameController.text,
        category: _category,
        // "You" is added by the service with your real user ID.
        others: _selected.where((p) => p != you).toList(),
      );
      if (!mounted) return;
      // pushReplacement: pressing Back from the new group returns to Home,
      // not to this (now finished) form.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => GroupDetail(groupId: group.id)),
      );
      showAppToast(context, '${group.name} created');
    } on GroupFailure catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppToast(context, e.message); // error state
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(
    'New Group',
    Form(
      key: _formKey,
      // Show errors as soon as the user edits a field after the first submit.
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Start from a template', style: AppText.section),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.45,
            children: [
              for (final t in _templates)
                _TemplateCard(
                  title: t.title,
                  subtitle: t.subtitle,
                  icon: categoryNamed(t.category).icon,
                  selected: _category.name == t.category,
                  onTap: () => _pickTemplate(t.category),
                ),
            ],
          ),
          const SizedBox(height: 16),

          const _Label('Group name'),
          TextFormField(
            key: const ValueKey('group-name'),
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            maxLength: 40,
            decoration: const InputDecoration(
              hintText: 'e.g. Baguio Trip',
              counterText: '', // hide the "0/40" counter
            ),
            validator: _validateName,
          ),
          const SizedBox(height: 12),

          const _Label('Category'),
          DropdownButtonFormField<GroupCategory>(
            key: const ValueKey('group-category'),
            initialValue: _category,
            isExpanded: true,
            items: [
              for (final c in groupCategories)
                DropdownMenuItem(
                  value: c,
                  child: Text(
                    '${c.name} - ${c.hint}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (c) => setState(() => _category = c!),
            validator: (c) => c == null ? 'Choose a category' : null,
          ),
          const SizedBox(height: 12),

          const _Label('Members'),
          // A FormField lets this non-text input join the Form's validation.
          FormField<List<Person>>(
            initialValue: _selected,
            validator: _validateMembers,
            builder: (field) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final p in _friends.toList()..insert(0, you))
                      _SelectableAvatar(
                        person: p,
                        selected: _selected.contains(p),
                        onTap: () => _toggleMember(p, field),
                      ),
                    _AddCircle(onTap: () => _addNewPerson(field)),
                  ],
                ),
                if (field.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      field.errorText!,
                      style: const TextStyle(color: errorFg, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Invite by link or QR after creating. Guests don't need the app.",
            style: AppText.caption,
          ),
        ],
      ),
    ),
    bottom: Btn(
      _saving ? 'Creating…' : 'Create Group',
      _saving ? null : _submit,
    ),
  );
}

/// Small grey label above each input (Figma style).
class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(fontSize: 12, color: ink)),
  );
}

/// Template card: icon, title, subtitle; green border + check when selected.
class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title, subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? green : border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: mint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: green, size: 18),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: muted),
              ),
            ],
          ),
          if (selected)
            const Positioned(
              top: 0,
              right: 0,
              child: CircleAvatar(
                radius: 10,
                backgroundColor: green,
                child: Icon(Icons.check, size: 14, color: Colors.white),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Member avatar that shows a green check badge when selected.
class _SelectableAvatar extends StatelessWidget {
  const _SelectableAvatar({
    required this.person,
    required this.selected,
    required this.onTap,
  });

  final Person person;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Opacity(
      opacity: selected ? 1 : 0.4,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Avatar(person, size: 44),
          if (selected)
            const Positioned(
              right: -2,
              bottom: -2,
              child: CircleAvatar(
                radius: 8,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 6.5,
                  backgroundColor: green,
                  child: Icon(Icons.check, size: 9, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Dashed-looking "+" circle for adding a new person.
class _AddCircle extends StatelessWidget {
  const _AddCircle({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    customBorder: const CircleBorder(),
    child: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: muted),
      ),
      child: const Icon(Icons.add, color: muted, semanticLabel: 'Add person'),
    ),
  );
}
