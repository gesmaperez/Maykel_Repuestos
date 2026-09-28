import 'package:flutter/material.dart';

import '../api_service.dart';
import '../config.dart';

/// Muestra el diálogo de acceso al panel admin. Devuelve `true` si el login
/// fue exitoso, `false`/`null` en caso contrario.
Future<bool?> mostrarLoginAdmin(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (_) => const _AdminLoginDialog(),
  );
}

class _AdminLoginDialog extends StatefulWidget {
  const _AdminLoginDialog();

  @override
  State<_AdminLoginDialog> createState() => _AdminLoginDialogState();
}

class _AdminLoginDialogState extends State<_AdminLoginDialog> {
  final _usuarioCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _verificando = false;
  bool _error = false;

  @override
  void dispose() {
    _usuarioCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    final usuario = _usuarioCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (usuario.isEmpty || password.isEmpty) {
      setState(() => _error = true);
      return;
    }
    setState(() {
      _verificando = true;
      _error = false;
    });

    final ok = await ApiService.instance.loginAdmin(usuario, password);

    if (!mounted) return;
    setState(() => _verificando = false);

    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Acceso administrador',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _usuarioCtrl,
                decoration: const InputDecoration(labelText: 'Usuario'),
                onSubmitted: (_) => _entrar(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordCtrl,
                decoration: const InputDecoration(labelText: 'Contraseña'),
                obscureText: true,
                onSubmitted: (_) => _entrar(),
              ),
              if (_error) ...[
                const SizedBox(height: 10),
                Text(
                  'Usuario o contraseña incorrectos.',
                  style: TextStyle(color: AppColors.bad, fontSize: 12.5),
                ),
              ],
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: _verificando ? null : _entrar,
                child: _verificando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Entrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
