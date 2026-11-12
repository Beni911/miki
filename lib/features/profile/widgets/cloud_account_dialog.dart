import 'package:flutter/material.dart';
import '../../../data/sync_service.dart';

class CloudAccountDialog extends StatefulWidget {
  final RemoteGateway remote;
  const CloudAccountDialog({super.key, required this.remote});

  @override
  State<CloudAccountDialog> createState() => _CloudAccountDialogState();
}

class _CloudAccountDialogState extends State<CloudAccountDialog> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    await _run(() async {
      await widget.remote.signIn(_email.text.trim(), _password.text);
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  Future<void> _signUp() async {
    await _run(() async {
      final authenticated = await widget.remote.signUp(_email.text.trim(), _password.text);
      if (!mounted) return;
      if (authenticated) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _message = 'Check your email to confirm the account, then sign in.');
      }
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.remote.userEmail;
    return AlertDialog(
      title: const Text('Cloud account'),
      content: email != null
          ? Text('Signed in as $email. This device is linked to this account.')
          : SizedBox(
              width: 360,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                TextField(
                  controller: _password,
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: const InputDecoration(labelText: 'Password (at least 6 characters)'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  Text(_message!),
                ],
              ]),
            ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Close'),
        ),
        if (email != null)
          FilledButton(
            onPressed: _busy
                ? null
                : () => _run(() async {
                      await widget.remote.signOut();
                      if (mounted) Navigator.of(context).pop(true);
                    }),
            child: const Text('Sign out'),
          )
        else ...[
          TextButton(onPressed: _busy ? null : _signUp, child: const Text('Create account')),
          FilledButton(onPressed: _busy ? null : _signIn, child: const Text('Sign in')),
        ],
      ],
    );
  }
}
