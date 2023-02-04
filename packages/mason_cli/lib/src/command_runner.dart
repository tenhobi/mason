import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:cli_completion/cli_completion.dart';
import 'package:mason/mason.dart' hide packageVersion;
import 'package:mason_api/mason_api.dart';
import 'package:mason_cli/src/commands/commands.dart';
import 'package:mason_cli/src/version.dart';
import 'package:pub_updater/pub_updater.dart';

/// The package name.
const packageName = 'mason_cli';

/// The executable name.
const executableName = 'mason';

/// {@template mason_command_runner}
/// A [CommandRunner] for the Mason CLI.
/// {@endtemplate}
class MasonCommandRunner extends CompletionCommandRunner<int> {
  /// {@macro mason_command_runner}
  MasonCommandRunner({
    Logger? logger,
    PubUpdater? pubUpdater,
    MasonApi? masonApi,
  })  : _logger = logger ?? Logger(),
        _pubUpdater = pubUpdater ?? PubUpdater(),
        _masonApi = masonApi ?? MasonApi(hostedUri: BricksJson.hostedUri),
        super(executableName, '🧱  mason \u{2022} lay the foundation!') {
    argParser.addFlags();
    addCommand(AddCommand(logger: _logger));
    addCommand(CacheCommand(logger: _logger));
    addCommand(BundleCommand(logger: _logger));
    addCommand(GetCommand(logger: _logger));
    addCommand(InitCommand(logger: _logger));
    addCommand(ListCommand(logger: _logger));
    addCommand(LoginCommand(logger: _logger, masonApi: _masonApi));
    addCommand(LogoutCommand(logger: _logger, masonApi: _masonApi));
    addCommand(MakeCommand(logger: _logger));
    addCommand(NewCommand(logger: _logger));
    addCommand(PublishCommand(logger: _logger, masonApi: _masonApi));
    addCommand(RemoveCommand(logger: _logger));
    addCommand(SearchCommand(logger: _logger, masonApi: _masonApi));
    addCommand(UnbundleCommand(logger: _logger));
    addCommand(UpdateCommand(logger: _logger, pubUpdater: _pubUpdater));
    addCommand(UpgradeCommand(logger: _logger));
  }

  final Logger _logger;
  final MasonApi _masonApi;
  final PubUpdater _pubUpdater;

  @override
  Future<int> run(Iterable<String> args) async {
    try {
      return await runCommand(parse(args)) ?? ExitCode.success.code;
    } on FormatException catch (e) {
      _logger
        ..err(e.message)
        ..info('')
        ..info(usage);
      return ExitCode.usage.code;
    } on UsageException catch (e) {
      _logger
        ..err(e.message)
        ..info('')
        ..info(e.usage);
      return ExitCode.usage.code;
    } on MasonException catch (e) {
      _logger.err(e.message);
      return ExitCode.usage.code;
    } on ProcessException catch (error) {
      _logger.err(error.message);
      return ExitCode.unavailable.code;
    } catch (error) {
      _logger.err('$error');
      return ExitCode.software.code;
    } finally {
      _masonApi.close();
    }
  }

  @override
  Future<int?> runCommand(ArgResults topLevelResults) async {
    if (topLevelResults.command?.name == 'completion') {
      await super.runCommand(topLevelResults);
      return ExitCode.success.code;
    }

    if (topLevelResults['verbose'] == true) _logger.level = Level.verbose;

    int? exitCode = ExitCode.unavailable.code;
    if (topLevelResults['version'] == true) {
      _logger.info(packageVersion);
      exitCode = ExitCode.success.code;
    } else {
      exitCode = await super.runCommand(topLevelResults);
    }
    if (topLevelResults.command?.name != 'update') await _checkForUpdates();
    return exitCode;
  }

  Future<void> _checkForUpdates() async {
    _logger.detail('\n[updater] checking for updates...');

    try {
      final latestVersion = await _pubUpdater.getLatestVersion(packageName);
      _logger.detail('[updater] latest version is $latestVersion.');

      final isUpToDate = packageVersion == latestVersion;
      if (isUpToDate) {
        _logger.detail('[updater] no updates available.');
        return;
      }

      if (!isUpToDate) {
        _logger.detail('[updater] update available.');
        final changelogLink = lightCyan.wrap(
          styleUnderlined.wrap(
            link(
              uri: Uri.parse(
                'https://github.com/felangel/mason/releases/tag/mason_cli-v$latestVersion',
              ),
            ),
          ),
        );
        _logger
          ..info('')
          ..info(
            '''
${lightYellow.wrap('Update available!')} ${lightCyan.wrap(packageVersion)} \u2192 ${lightCyan.wrap(latestVersion)}
${lightYellow.wrap('Changelog:')} $changelogLink
Run ${cyan.wrap('mason update')} to update''',
          );
      }
    } catch (error, stackTrace) {
      _logger.detail(
        '[updater] update check error.\n$error\n$stackTrace',
      );
    } finally {
      _logger.detail('[updater] update check complete.');
    }
  }
}

extension on ArgParser {
  void addFlags() {
    addFlag(
      'version',
      negatable: false,
      help: 'Print the current version.',
    );
    addFlag(
      'verbose',
      negatable: false,
      help: 'Output additional logs.',
    );
  }
}
