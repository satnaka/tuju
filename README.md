# TuJu

TuJu is an iPhone navigation app for finding a place, comparing driving routes and starting turn-by-turn guidance in Apple Maps. It also includes an offline Kuala Lumpur journey that previews the lane guidance, R&R stops and rewards from the TuJu design.

**Need directions now?** Apple Maps opens directly from these links. [Open Apple Maps](https://maps.apple.com/) · [Directions to KL Sentral](https://maps.apple.com/directions?destination=KL%20Sentral%2C%20Kuala%20Lumpur%2C%20Malaysia&mode=driving)

## Take a trip in TuJu

1. Open **Home** or **Map**. Tap **Show my location** to center the map, or pan to the area you want to explore.
2. Tap **Search places or addresses**, enter a destination and select a result. **Drive with TuJu** shows available routes from your current location. MapKit search and directions require a network connection.
3. Compare time and distance, check alternatives or add a stop. Tap **Start navigation in Apple Maps** for turn-by-turn guidance. You can also open the destination in Apple Maps when TuJu cannot get a location fix.
4. For a ride, choose **Compare ride options**. Review the destination and open the provider to check availability, enter pickup details and book.

For the illustrated journey, open search and choose **Explore the One Utama concept route**. **Preview R&R stops** on Home opens its sample rest stops. The parking counts, traffic scenarios, ride fares and vouchers in this preview are simulated. Profile preferences, saved destinations, journey history and demo rewards are stored on the device.

## Run the iPhone app

This repository distributes the source. To run TuJu, use Xcode on a Mac with an iPhone simulator or a device running iOS 17 or later. Install Node.js 24, pnpm 11 and CocoaPods. The Home panel and tab bar use a licensed HeroUI Native Pro package. Authenticate with your HeroUI license before installing dependencies. [HeroUI Native Pro installation](https://heroui.pro/docs/native/getting-started/installation)

From the project root, run

```sh
pnpm --dir NativeUI install --frozen-lockfile
pod install
open TuJu.xcworkspace
```

Select the **TuJu** scheme and an iPhone destination, then press **Run**. For a Mac preview, select **My Mac (Mac Catalyst)**. Xcode bundles the React Native controls into the app. To test live directions in Simulator, set a simulated location and allow location access when TuJu asks.

## Account sign-in

TuJu uses the system browser and OpenID Connect for account sign-in. To enable it, register a native app in your organization's identity provider and configure the issuer, public client ID and callback. Enable Apple, Google or MyDigital ID on that provider's hosted sign-in page using your organization's registrations. The default build opens in guest mode. [Account configuration](Configuration/Authentication.md)

## Design and implementation

The first-launch tour, Drive and Ride choices, rewards and navigation preferences draw on the Prototype 1 canvas. The map controls use HeroUI Native components hosted in SwiftUI with React Native Fabric. Apple Liquid Glass is used on supported OS versions. [Prototype 1](https://www.figma.com/design/5njuLGsk4xiY1H613dOfja/GDC601---Communication-Studio-2?node-id=1-2) · [Main UI Screen](https://www.figma.com/design/5njuLGsk4xiY1H613dOfja/GDC601---Communication-Studio-2?node-id=72-9085) · [React Native controls](NativeUI/TuJuControls.jsx) · [Swift host](TuJu/ReactNative)
