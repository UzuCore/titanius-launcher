part of 'package:titanius/pages/scraper.dart';

class ScraperPasswordPage extends HookConsumerWidget {
  const ScraperPasswordPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    useGamepad(ref, (location, key) {
      if (location != "/settings/scraper/password") return;
      if (key == GamepadButton.b) {
        GoRouter.of(context).pop();
      }
    });

    return settings.when(
      data: (settings) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Password'),
          ),
          bottomNavigationBar: const PromptBar(
            navigations: [],
            actions: [
              GamepadPrompt([GamepadButton.a], "Change"),
              GamepadPrompt([GamepadButton.b], "Apply"),
            ],
          ),
          body: Theme(
            data: Theme.of(context).copyWith(
              textTheme: Theme.of(context).textTheme.apply(
                    fontFamily: 'Roboto',
                  ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(settings.screenScraperPwd ?? "", style: const TextStyle(fontFamily: 'Roboto', fontSize: 30)),
                  Container(height: 20),
                  SizedBox(
                    width: 2 * MediaQuery.sizeOf(context).width / 3,
                    child: OnscreenKeyboard(
                      value: settings.screenScraperPwd ?? "",
                      buttonColor: Theme.of(context).colorScheme.background.lighten(10),
                      focusColor: Theme.of(context).colorScheme.primary,
                      onChanged: (txt) async {
                        ref
                            .read(settingsRepoProvider)
                            .value!
                            .setScreenScraperPwd(txt ?? "")
                            .then((value) => ref.refresh(settingsProvider));
                      },
                      initialCase: InitialCase.LOWER_CASE,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, s) => const Scaffold(
        body: Center(
          child: Text("Error loading settings"),
        ),
      ),
    );
  }
}
