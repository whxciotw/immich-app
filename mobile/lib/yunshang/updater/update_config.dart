/// Configuration for the unofficial "yunshang" Immich Android build.
///
/// The app checks this GitHub repository for new releases instead of the
/// Play Store / F-Droid, because the build is signed with a different key and
/// uses the `app.alextran.immich.yunshang` package name.
const String kYunshangRepo = 'whxciotw/immich-app';
const String kYunshangReleaseBase = 'https://github.com/$kYunshangRepo';
const String kYunshangLatestReleasePage = '$kYunshangReleaseBase/releases/latest';
const String kYunshangLatestJsonUrl = '$kYunshangReleaseBase/releases/latest/download/latest.json';
const String kYunshangUpdateUserAgent = 'Immich-Yunshang-Updater';

const Duration kYunshangHttpTimeout = Duration(seconds: 20);
const Duration kYunshangCheckInterval = Duration(hours: 24);

const String kYunshangInstallerChannel = 'app.alextran.immich/yunshang_installer';
