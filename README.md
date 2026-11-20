# TuJu

TuJu is an interactive iPhone navigation concept set in Kuala Lumpur. Its Home panel and bottom menu use React Native and HeroUI Native Pro. SwiftUI presents the journey screens and MapKit provides live maps and directions. The featured journey to One Utama works offline.

## Try the concept

On a development Mac, install Node.js 24, pnpm 11 and CocoaPods. The JavaScript dependencies include a licensed HeroUI Native Pro package. A first-time developer can authenticate through the [official HeroUI Native Pro installer](https://heroui.pro/docs/native/getting-started/installation).

From the project root, install the pinned dependencies and open the workspace.

```sh
pnpm --dir NativeUI install --frozen-lockfile
pod install
open TuJu.xcworkspace
```

Select the **TuJu** scheme and an iPhone simulator with iOS 17 or later, then press **Run**. To try the same controls on your Mac, select **My Mac (Mac Catalyst)**. Xcode bundles the JavaScript and icons into the app, so the concept runs without a Metro development server.

1. From **Home**, tap **Search places or addresses** and choose **One Utama**.
2. Compare the three routes. Try **Avoid tolls**, inspect the toll details or add an R&R stop.
3. Start the preview to explore lane guidance, Simple Mode and the road-level choices. Open **Ride options** on the route screen to try a simulated pickup.
4. Open **Rewards** from Home to browse vouchers. Demo redemptions, saved destinations and trip history stay on the device.

The illustrative map, lane instructions, sample traffic, fares and vouchers are concept data. Live map features use Apple MapKit and require network access. The location button requests permission only when tapped. Driving and ride previews can be explored without granting access.

## Design

The visual reference is the **Main UI Screen (Finalized)** page. The Home panel uses Button from `heroui-native`. The four-item bottom menu uses Segment from `heroui-native-pro` with bundled SVG icons. Both controls render through React Native Fabric. SwiftUI supplies the selected tab, saved destinations and recent places, and handles the actions from the controls.

The React Native components live in [NativeUI/TuJuControls.jsx](NativeUI/TuJuControls.jsx). The Swift and Objective-C++ host lives in [TuJu/ReactNative](TuJu/ReactNative). Source artwork remains in the app’s asset catalog.

[Open the source design in Figma](https://www.figma.com/design/5njuLGsk4xiY1H613dOfja/GDC601---Communication-Studio-2?node-id=72-9085)
