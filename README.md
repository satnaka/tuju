# TuJu

TuJu is an interactive iPhone navigation concept set in Kuala Lumpur. It combines the supplied Figma artwork with HeroUI Pro, SwiftUI and MapKit. The featured journey to One Utama works offline.

## Try the concept

Open `TuJu.xcodeproj` in Xcode 16 or later, select the **TuJu** scheme and an iPhone simulator with iOS 17 or later, then press **Run**. To try the same screens on a Mac while an iOS simulator downloads, select **My Mac (Mac Catalyst)** and run the TuJu scheme.

1. From **Home**, tap **Search places or addresses** and choose **One Utama**.
2. Compare the three routes. Try **Avoid tolls**, inspect the toll details or add an R&R stop.
3. Start the preview to explore lane guidance, Simple Mode and the road-level choices. Open **Ride options** on the route screen to try a simulated pickup.
4. Open **Rewards** from Home to browse vouchers. Demo redemptions, saved destinations and trip history stay on the device.

The illustrative map, lane instructions, sample traffic, fares and vouchers are concept data. Live map features use Apple MapKit and require network access. The location button requests permission only when tapped. Driving and ride previews can be explored without granting access.

## Design

The visual reference is the **Main UI Screen (Finalized)** page. On Home, the destination and R&R rows use HeroUI Pro ItemCard, and search and shortcuts use HeroUI Button. The shared bottom navigation uses HeroUI Pro Navbar. A local WebKit view displays these controls and passes taps to SwiftUI. The route, ride and account screens use the Pro Glass theme’s surface and interaction values in SwiftUI.

Xcode includes a prebuilt copy of the controls for both iPhone and Mac. No Node.js or HeroUI login is needed to run the app. See the [HeroUI build instructions](HeroUI/README.md) to edit and regenerate the controls.

[Open the source design in Figma](https://www.figma.com/design/5njuLGsk4xiY1H613dOfja/GDC601---Communication-Studio-2?node-id=72-9085)
