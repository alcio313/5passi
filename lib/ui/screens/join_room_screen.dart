import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/tracker_provider.dart';

/// Screen to configure room name, password (E2EE), display name, and CARTO key
class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _groupController;
  late final TextEditingController _pwdController;
  late final TextEditingController _nameController;
  late final TextEditingController _cartoKeyController;
  late final TextEditingController _brokerController;

  bool _obscurePwd = true;
  bool _isLoading = false;
  bool _showAdvanced = false;

  @override
  void initState() {
    super.initState();
    final tracker = context.read<TrackerProvider>();
    _groupController = TextEditingController(text: tracker.groupDisplayName);
    _pwdController = TextEditingController();
    _nameController = TextEditingController(text: tracker.myName);
    _cartoKeyController = TextEditingController(text: tracker.cartoKey);
    _brokerController = TextEditingController(text: tracker.brokerHost);
    _brokerUserController = TextEditingController(text: tracker.brokerUsername);
    _brokerPasswordController = TextEditingController(text: tracker.brokerPassword);

    // Request smartphone permissions immediately on app launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<TrackerProvider>().requestStartupPermissions();
      }
    });
  }

  late final TextEditingController _brokerUserController;
  late final TextEditingController _brokerPasswordController;

  @override
  void dispose() {
    _groupController.dispose();
    _pwdController.dispose();
    _nameController.dispose();
    _cartoKeyController.dispose();
    _brokerController.dispose();
    _brokerUserController.dispose();
    _brokerPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleJoin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final tracker = context.read<TrackerProvider>();

    final success = await tracker.joinRoom(
      groupName: _groupController.text,
      password: _pwdController.text,
      userName: _nameController.text,
      cartoKey: _cartoKeyController.text,
      brokerHost: _brokerController.text,
      brokerUsername: _brokerUserController.text,
      brokerPassword: _brokerPasswordController.text,
    );

    setState(() => _isLoading = false);

    if (!success && mounted) {
      final errorDetail = tracker.lastError;
      final msg = (errorDetail != null && errorDetail.isNotEmpty)
          ? 'Errore MQTT: $errorDetail'
          : 'Errore di connessione al broker MQTT. Verifica la rete o prova il broker alternativo nelle Opzioni.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Opzioni',
            textColor: Colors.white,
            onPressed: () {
              setState(() => _showAdvanced = true);
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Icon & Title
                  Center(
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.radarCore, width: 2.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x6600E5FF),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.satellite_alt,
                        color: AppColors.radarCore,
                        size: 38,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    '5passi',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tracciamento GPS in tempo reale protetto con crittografia E2EE e supporto a schermo spento',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Group Name Field
                  TextFormField(
                    controller: _groupController,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'Nome Gruppo o Stanza',
                      labelStyle: const TextStyle(color: Colors.white70),
                      hintText: 'es. Volantini X, Escursione',
                      hintStyle: const TextStyle(color: Colors.white30),
                      prefixIcon: const Icon(Icons.groups, color: AppColors.primary),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Inserisci il nome della stanza' : null,
                  ),
                  const SizedBox(height: 16),

                  // Room Password Field (E2EE)
                  TextFormField(
                    controller: _pwdController,
                    obscureText: _obscurePwd,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'Parola d\'ordine (Password E2EE)',
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(Icons.lock, color: AppColors.success),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePwd ? Icons.visibility : Icons.visibility_off,
                          color: Colors.white70,
                        ),
                        onPressed: () => setState(() => _obscurePwd = !_obscurePwd),
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Inserisci la password della stanza' : null,
                  ),
                  const SizedBox(height: 16),

                  // Display Name Field
                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'Tuo Nome Visualizzato',
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(Icons.person, color: AppColors.radarCore),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Advanced Options Toggle
                  TextButton.icon(
                    onPressed: () => setState(() => _showAdvanced = !_showAdvanced),
                    icon: Icon(
                      _showAdvanced ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.radarCore,
                    ),
                    label: Text(
                      _showAdvanced ? 'Nascondi Opzioni Avanzate' : 'Opzioni Avanzate (Broker MQTT e Mappa)',
                      style: const TextStyle(color: AppColors.radarCore, fontSize: 13),
                    ),
                  ),

                  if (_showAdvanced) ...[
                    const SizedBox(height: 8),

                    // MQTT Broker Host Field
                    TextFormField(
                      controller: _brokerController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Broker MQTT Host',
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintText: '02c32905ccdb4e97b9cd3860b9ae6f14.s1.eu.hivemq.cloud',
                        hintStyle: const TextStyle(color: Colors.white30),
                        prefixIcon: const Icon(Icons.hub_outlined, color: AppColors.radarCore),
                        suffixIcon: PopupMenuButton<String>(
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                          tooltip: 'Seleziona broker MQTT',
                          onSelected: (val) {
                            setState(() {
                              _brokerController.text = val;
                            });
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: '02c32905ccdb4e97b9cd3860b9ae6f14.s1.eu.hivemq.cloud',
                              child: Text('HiveMQ Cloud UE Dedicato (TLS 8883)'),
                            ),
                            PopupMenuItem(
                              value: 'broker.emqx.io',
                              child: Text('broker.emqx.io (Pubblico - TLS 8883)'),
                            ),
                            PopupMenuItem(
                              value: 'broker.hivemq.com',
                              child: Text('broker.hivemq.com (Pubblico Alternativo)'),
                            ),
                          ],
                        ),
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // MQTT Username Field
                    TextFormField(
                      controller: _brokerUserController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'MQTT Username (se richiesto dal broker)',
                        labelStyle: const TextStyle(color: Colors.white70),
                        prefixIcon: const Icon(Icons.account_circle_outlined, color: AppColors.radarCore),
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // MQTT Password Field
                    TextFormField(
                      controller: _brokerPasswordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'MQTT Password (se richiesto dal broker)',
                        labelStyle: const TextStyle(color: Colors.white70),
                        prefixIcon: const Icon(Icons.password_outlined, color: AppColors.radarCore),
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // CARTO Key Field
                    TextFormField(
                      controller: _cartoKeyController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Chiave API CARTO Basemaps (Opzionale)',
                        labelStyle: const TextStyle(color: Colors.white70),
                        prefixIcon: const Icon(Icons.map, color: AppColors.warning),
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Submit Button
                  SizedBox(
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleJoin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'ENTRA NELLA STANZA 🚀',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // E2EE Info Callout
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.shield_outlined, color: AppColors.success, size: 22),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Tutte le posizioni sono cifrate localmente con AES-GCM 256. Nessun server memorizza i tuoi dati.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
