# shampic
 App for taking photos of robots at competition (Pit Scouting)

## Builds
- Bump the major version number for a major app redesign. Bump the minor version for new features and bump the patch number for bug fixes.
    - Ex. 1.5.0 --> 2.0.0 for a major redesign
    - Ex. 1.5.0 --> 1.6.0 when adding new features with backwards compatibility
    - Ex. 1.5.0 --> 1.5.1 when patching bugs
- Increase the build number by one (i.e. 1.5.0+1 --> 1.5.1+2)
- Android
    - In Android Studio, go to Build > Flutter > Build App Bundle
    - Go to [Google Play Console](https://play.google.com/console)
    - Select the ShamScout Mobile and navigate to the Production Section, and click "Create new release"
    - Make sure the build finished successfully (exit code 0)
    - Upload `app-release.aab` in `build\app\outputs\bundle\release\` to the Play Store
    - Enter the version number as the name
    - Write any relevant changelog information in the description section
- Apple
    - Use Odevio to publish a production build
    - In App Store Connect, go to the Testflight versions and "Manage" the missing compliance (the app doesn't use any encryption algorithms)
    - In the App Store section, add version information, save it, and submit for review