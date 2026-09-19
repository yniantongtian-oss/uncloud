import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'controllers/devices_controller.dart';
import 'controllers/settings_controller.dart';
import 'controllers/transfer_controller.dart';
import 'l10n/app_localizations.dart';
import 'l10n/locale_controller.dart';
import 'services/core_cli.dart';
import 'services/discovery_service.dart';
import 'services/receiver_service.dart';
import 'services/transfer_service.dart';
import 'ui/home/home_shell.dart';
import 'ui/onboarding/onboarding_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final localeController = LocaleController();
  await localeController.load();

  CoreCli? cli;
  ReceiverService? receiver;
  if (!kIsWeb) {
    cli = await CoreCli.detect();
    if (cli != null) {
      receiver = ReceiverService(cli);
      await receiver.start();
    }
  }

  runApp(UncloudApp(
    localeController: localeController,
    coreCli: cli,
    receiver: receiver,
  ));
}

/// Root widget: wires providers, theme and localization.
class UncloudApp extends StatelessWidget {
  const UncloudApp({
    super.key,
    required this.localeController,
    this.coreCli,
    this.receiver,
  });

  final LocaleController localeController;
  final CoreCli? coreCli;
  final ReceiverService? receiver;

  @override
  Widget build(BuildContext context) {
    final useCore = coreCli != null;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LocaleController>.value(value: localeController),
        ChangeNotifierProvider<SettingsController>(
            create: (_) => SettingsController()),
        ChangeNotifierProvider<DevicesController>(
          create: (_) => DevicesController(
            discovery: DiscoveryService(demo: !useCore, cli: coreCli),
          ),
        ),
        ChangeNotifierProvider<TransferController>(
          create: (_) => TransferController(
            service: TransferService(
              transport: useCore
                  ? CliTransferTransport(coreCli!)
                  : const DemoTransferTransport(),
            ),
          ),
        ),
        Provider<ReceiverService?>.value(value: receiver),
        Provider<CoreCli?>.value(value: coreCli),
      ],
      child: Consumer2<LocaleController, SettingsController>(
        builder: (context, locale, settings, _) {
          const seed = Colors.teal;
          return MaterialApp(
            onGenerateTitle: (context) => context.l10n.appTitle,
            debugShowCheckedModeBanner: false,
            themeMode: settings.themeMode,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(seedColor: seed),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: seed,
                brightness: Brightness.dark,
              ),
            ),
            locale: locale.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const OnboardingGate(),
          );
        },
      ),
    );
  }
}

/// Shows onboarding on first launch, otherwise the main shell.
class OnboardingGate extends StatefulWidget {
  const OnboardingGate({super.key});

  static const _seenKey = 'uncloud.seenOnboarding';

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  bool? _seen;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      setState(() => _seen = prefs.getBool(OnboardingGate._seenKey) ?? false);
    });
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(OnboardingGate._seenKey, true);
    setState(() => _seen = true);
  }

  @override
  Widget build(BuildContext context) {
    final seen = _seen;
    if (seen == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!seen) {
      return OnboardingPage(onDone: _completeOnboarding);
    }
    return const HomeShell();
  }
}
